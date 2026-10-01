# Module 07 — Bridging Legacy Code

> Roadmap: [[00 - Roadmap]] · Terms: [[Glossary]] · Prev: [[06 - Sendable and Data-Race Safety]] ·
> Next: [[08 - Structured Concurrency]]
> **Goal:** wrap any callback, delegate or GCD API in async without leaking or hanging.
> Drill: [[Drill 07 - Wrap a Delegate]]

---

## 1. Why this is module 07 and not module 12

Because this is what you'll actually be doing. Nobody starts a greenfield Swift 6 app — you
have a codebase full of completion handlers, delegates and dispatch queues, and the job is to
build an async surface over it one API at a time.

That's also the good news: **you don't have to migrate everything.** You wrap at the edges and
the async world grows inward.

---

## 2. Continuations — the bridge primitive

A continuation is the "resume me later" token from [[01 - Mental Model]] §5, handed to you
directly.

```swift
func fetchUser(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetchUser(id: id) { user, error in
            if let user {
                continuation.resume(returning: user)
            } else {
                continuation.resume(throwing: error ?? APIError.unknown)
            }
        }
    }
}
```

Four variants:

| | Non-throwing | Throwing |
| :--- | :--- | :--- |
| **Checked** (use this) | `withCheckedContinuation` | `withCheckedThrowingContinuation` |
| **Unsafe** (perf only) | `withUnsafeContinuation` | `withUnsafeThrowingContinuation` |

### The two laws ⚠️

> **A continuation must be resumed exactly once.**

| Violation | Consequence |
| :--- | :--- |
| Resume **zero** times | The task suspends **forever**. A silent hang, no crash, no log |
| Resume **twice** | Crash (checked) or memory corruption (unsafe) |

Checked continuations detect both and tell you — "SWIFT TASK CONTINUATION MISUSE" — which is
why you always start with checked. Switch to unsafe only if you've profiled and proven the
overhead matters, which for a network call it never will.

The dangerous shape is a callback with multiple paths:

```swift
// ❌ the guard returns without resuming → permanent hang
legacyFetch { data, error in
    guard let data else { return }          // 💀
    continuation.resume(returning: data)
}

// ✅ every path resumes
legacyFetch { data, error in
    if let data { continuation.resume(returning: data) }
    else { continuation.resume(throwing: error ?? APIError.unknown) }
}
```

> When reviewing a continuation, trace **every** exit path of the callback and confirm each one
> resumes exactly once. This is a mechanical check and it catches real production hangs.

---

## 3. Making continuations cancellable

A plain continuation ignores cancellation — cancelling the task leaves the underlying work
running and the continuation waiting. Pair it with `withTaskCancellationHandler`:

```swift
func download(_ url: URL) async throws -> Data {
    let task = LegacyDownloadTask(url: url)

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            task.start { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let e):    continuation.resume(throwing: e)
                }
            }
        }
    } onCancel: {
        task.cancel()          // must be Sendable & safe to call from any domain
    }
}
```

Note the ordering hazard: `onCancel` can fire **before** the operation closure starts, if the
task was already cancelled. Your `cancel()` must tolerate being called at any time, including
before `start`. More on cancellation in [[09 - Tasks, Cancellation and Priority]].

---

## 4. Delegates → `AsyncStream`

A delegate delivers *many* callbacks over time, so a continuation (one resume) is the wrong
shape. Use `AsyncStream`:

```swift
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private var continuation: AsyncStream<CLLocation>.Continuation?
    private let manager = CLLocationManager()

    var locations: AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.startUpdatingLocation()

            continuation.onTermination = { @Sendable _ in
                self.manager.stopUpdatingLocation()     // ← cleanup, don't skip this
            }
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        locs.forEach { continuation?.yield($0) }
    }
}

// usage
for await location in provider.locations {
    update(location)
}
```

`onTermination` is the part people forget, and forgetting it means the hardware keeps running
after the consumer walks away. It fires when the stream finishes *or* when the consuming task
is cancelled. Full treatment in [[10 - AsyncSequence and AsyncStream]].

---

## 5. Completion handlers you own

If you control the API, don't wrap it — **add** an async version and keep both during the
transition:

```swift
extension APIClient {
    // existing
    func fetch(_ path: String, completion: @escaping (Result<Data, Error>) -> Void) { }

    // new, in terms of the old
    func fetch(_ path: String) async throws -> Data {
        try await withCheckedThrowingContinuation { c in
            fetch(path) { c.resume(with: $0) }      // `resume(with:)` takes a Result directly
        }
    }
}
```

`continuation.resume(with: Result)` is the tidiest form and removes a whole class of
"forgot a path" bugs, because a `Result` has exactly two cases and both resume.

Then migrate callers one at a time and delete the old method when the last one is gone.

**Objective-C gets this for free.** A method whose last parameter is a completion handler is
automatically exposed as `async` in Swift:

```objc
- (void)fetchUserWithID:(NSString *)id completion:(void (^)(User * _Nullable, NSError * _Nullable))completion;
```
```swift
let user = try await client.fetchUser(withID: id)     // synthesised
```
Check for this before hand-writing a wrapper — a great deal of UIKit and Foundation already
has async variants you don't need to build.

---

## 6. GCD interop

| Legacy | Modern |
| :--- | :--- |
| `DispatchQueue.main.async { }` | `Task { @MainActor in }` |
| `DispatchQueue.global().async { }` | `Task.detached { }` or `@concurrent` func |
| Serial queue guarding state | `actor` |
| `DispatchGroup` | `withTaskGroup` |
| `DispatchQueue.concurrentPerform` | `withTaskGroup` |
| `DispatchSemaphore` for mutual exclusion | `actor` or `Mutex` |
| `DispatchSemaphore` for waiting | **restructure** — there is no equivalent, by design |
| `asyncAfter(deadline:)` | `try await Task.sleep(for:)` |

That second-to-last row is the one that causes production incidents:

```swift
// ☠️ DO NOT — blocks a cooperative pool thread; can deadlock the app
let sem = DispatchSemaphore(value: 0)
Task { data = await fetch(); sem.signal() }
sem.wait()
```

With ~6 pool threads, six of these deadlock your app permanently. There is no safe version. The
answer is always to make the caller `async`. If the caller is a synchronous framework method
you can't change, the answer is `Task { }` plus handling the result asynchronously — accept
that the value arrives later, because it does.

**Keeping a queue during migration.** If you must retain a `DispatchQueue` for ordering, give
an actor a custom executor backed by it rather than mixing paradigms at call sites. See §5 of
[[05 - MainActor and Global Actors]].

---

## 7. Notifications, KVO and Combine

**NotificationCenter** already vends an `AsyncSequence`:

```swift
for await note in NotificationCenter.default.notifications(named: .myEvent) {
    handle(note)
}
```
Note `Notification` isn't `Sendable`; extract what you need inside the loop rather than passing
the notification across a boundary.

**Combine** bridges via `.values`:

```swift
for await value in publisher.values {
    handle(value)
}
```
A clean migration path: keep the publisher, consume it with `for await`, and delete the
`sink`/`store(in:)` bookkeeping. Cancellation comes from the task instead of `AnyCancellable`.

**KVO / target-action** — wrap as `AsyncStream`, same shape as §4.

---

## 8. Pitfalls

**8.1 — Continuation leaks.** The #1 bridging bug, and it presents as "the app hangs sometimes"
with no crash log. Always checked, always trace every path.

**8.2 — Capturing `self` strongly in the callback.** Retain cycles didn't go away. `[weak self]`
still applies inside continuation bodies and `onTermination`.

**8.3 — Wrapping an API that's already async.** Check for a Swift async overload first;
Foundation and UIKit have many.

**8.4 — Assuming the callback fires on the thread you expect.** Legacy APIs vary wildly. Don't
touch UI in the callback body — resume the continuation and let isolation handle the rest.

**8.5 — Bridging *out* of async with a semaphore.** See §6. The temptation peaks at exactly
the moment it's most dangerous.

**8.6 — Forgetting `onTermination` on an `AsyncStream`.** Leaks whatever hardware or
subscription the stream started.

---

## 9. Drill gate

→ **[[Drill 07 - Wrap a Delegate]]**

Two parts: wrap a completion-handler API with a cancellable continuation, then wrap a
multi-callback delegate as an `AsyncStream` with working cleanup. Then deliberately write the
`guard ... else { return }` bug from §2 and watch your program hang — so you recognise the
symptom in production, where it won't come with a label.
