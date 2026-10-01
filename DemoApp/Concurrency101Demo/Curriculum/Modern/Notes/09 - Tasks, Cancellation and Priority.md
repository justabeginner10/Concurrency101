# Module 09 — Tasks, Cancellation and Priority

> Roadmap: [[00 - Roadmap]] · Terms: [[Glossary]] · Prev: [[08 - Structured Concurrency]] ·
> Next: [[10 - AsyncSequence and AsyncStream]]
> **Goal:** cancel correctly, and stop using `Task { }` where it doesn't belong.
> Drill: [[Drill 09 - Cancel It Properly]]

---

## 1. `Task { }` vs `Task.detached { }`

| | `Task { }` | `Task.detached { }` |
| :--- | :--- | :--- |
| Actor isolation | **Inherits** the enclosing lexical context | **Nothing** — nonisolated |
| Priority | Inherits | Default, unless specified |
| Task-local values | Inherits | Nothing |
| Cancellation | Inherits state at creation; **not** linked afterwards | Nothing |
| Structured | ❌ unstructured | ❌ unstructured |

Both are unstructured: they escape the scope, and nobody waits for them.

> **You almost never want `Task.detached`.** It exists for work that must genuinely escape all
> context — a fire-and-forget log flush at app termination, say. Every other use of it in real
> code that I've seen was someone trying to force work off the main actor, and the right tool
> for that is `@concurrent nonisolated` (see [[11 - Swift 6.2 and Modern Defaults]]).

The inheritance subtlety worth repeating from [[03 - Isolation - The Core Concept]] §3.6:

```swift
@MainActor
func tap() {
    Task {  here("A") }           // MAIN — inherited @MainActor from lexical context
    Task.detached { here("B") }   // bg   — inherited nothing
}
```

"Inherits cancellation state at creation" is also a trap: a `Task { }` created inside a
cancelled task starts cancelled, but a `Task { }` created *before* cancellation is **not**
cancelled when its creator is. Unstructured tasks aren't in the tree.

---

## 2. Cancellation is cooperative

> **Cancelling a task sets a flag. It does not stop anything.**

Nothing is interrupted, no exception is injected, no thread is killed. Your code must *check*.
Code that never checks runs to completion after cancellation, wasting the work and — worse —
committing its side effects.

Three ways to check:

```swift
// 1. Throw if cancelled (usual choice)
try Task.checkCancellation()

// 2. Inspect and decide (when you need cleanup or a partial result)
if Task.isCancelled { return partialResults }

// 3. Let a cancellation-aware API throw for you
try await Task.sleep(for: .seconds(1))   // throws CancellationError immediately on cancel
```

Where to put checks: **at loop boundaries and before expensive or irreversible steps.**

```swift
func processAll(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []
    for item in items {
        try Task.checkCancellation()         // ← cheap, and it's the natural boundary
        results.append(try await process(item))
    }
    return results
}
```

Most `await`s on system APIs (`URLSession`, `Task.sleep`) already check and throw. A purely
CPU-bound loop checks nothing unless you add it — which is exactly the loop you most want to
be cancellable.

### Cancellation and side effects

```swift
func transfer() async throws {
    try Task.checkCancellation()
    let result = try await bank.debit(amount)     // ⚠️ irreversible
    try Task.checkCancellation()                  // ← cancelling HERE loses the money
    try await bank.credit(amount)
}
```

**Never check between two halves of an operation that must be atomic.** Do irreversible work
last, or make it idempotent and retryable. This is the same discipline as App Intents'
`perform()` being retriable, and it matters far more than the concurrency mechanics.

---

## 3. `withTaskCancellationHandler`

For work that can't poll — a continuation, a C API, a subscription:

```swift
func observe() async throws -> Value {
    let subscription = legacy.subscribe()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { c in
            subscription.onValue = { c.resume(returning: $0) }
        }
    } onCancel: {
        subscription.cancel()        // runs immediately on cancel, from any context
    }
}
```

Three things about `onCancel`:

- It runs **immediately** when cancellation happens, not at the next suspension point.
- It is `@Sendable` and runs in **no particular isolation** — it can't touch actor state
  directly. Capture a `Sendable` handle, not `self`.
- It can run **before** the operation body starts, if the task was already cancelled. Whatever
  you call there must tolerate that.

---

## 4. Storing and cancelling task handles

`Task { }` returns a handle. Discard it and you can never cancel the work.

```swift
@MainActor
final class SearchController {
    private var searchTask: Task<Void, Never>?

    func search(_ query: String) {
        searchTask?.cancel()                       // cancel the previous one
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))   // debounce
                try Task.checkCancellation()
                let results = try await api.search(query)
                self.results = results
            } catch is CancellationError {
                // expected — a newer search superseded this one
            } catch {
                self.error = error
            }
        }
    }

    deinit { searchTask?.cancel() }
}
```

This is the debounced-search pattern and it's worth memorising whole — `sleep` + `cancel` gives
you debouncing for free, because cancelling during the sleep throws before any request is made.

**In SwiftUI, prefer `.task`** — it does the storing and cancelling for you:

```swift
.task { await load() }                 // cancelled when the view disappears
.task(id: query) { await search(query) }  // cancelled + restarted when query changes
```

`.task(id:)` replaces the entire manual debounce/cancel dance above for most UI cases. Use the
manual version when the lifetime isn't a view's lifetime.

---

## 5. Priority

```swift
Task(priority: .userInitiated) { await load() }
```

| Priority | For |
| :--- | :--- |
| `.high` / `.userInitiated` | The user is waiting and watching |
| `.medium` | Default |
| `.low` / `.utility` | Progress-bar work |
| `.background` | Prefetch, cleanup, analytics |

**Priority escalation:** if a high-priority task awaits a low-priority one, the runtime raises
the low one — Swift's answer to priority inversion. It's automatic, but it only works when the
dependency is visible to the runtime (an `await`). Hide the dependency behind a semaphore and
you get a genuine inversion the runtime can't fix. One more reason not to block.

Don't micro-tune priorities. Defaults are right for almost everything; `.background` for
genuinely deferrable work is the one distinction that earns its keep.

---

## 6. Task-local values

The replacement for thread-local storage, which is meaningless here (§7.3, [[01 - Mental Model]]):

```swift
enum RequestContext {
    @TaskLocal static var traceID: String?
}

await RequestContext.$traceID.withValue("abc-123") {
    await handleRequest()        // and everything it awaits, transitively
}

func log(_ m: String) {
    print("[\(RequestContext.traceID ?? "-")] \(m)")
}
```

Values propagate down the **structured** task tree — child tasks and `Task { }` inherit,
`Task.detached` does not. The canonical use is request tracing and correlation IDs in logs;
it's also how `swift-log` and distributed tracing libraries carry context.

---

## 7. `Task.yield()` and `Task.immediate`

`Task.yield()` gives other tasks a turn. Use it in long CPU loops that would otherwise hog a
cooperative thread:

```swift
for (i, chunk) in chunks.enumerated() {
    process(chunk)
    if i % 100 == 0 { await Task.yield() }
}
```

It is **not** a synchronisation tool. `await Task.yield()` to "let the other thing finish
first" is a race with extra steps.

`Task.immediate { }` (Swift 6.2) starts the body **synchronously** on the current context until
its first suspension, rather than enqueueing it. Useful when you need the first part of the
work to happen now — e.g. setting `isLoading = true` before any hop — without an extra turn of
the run loop.

---

## 8. Pitfalls

**8.1 — Assuming `cancel()` stops the work.** It sets a flag. §2.

**8.2 — Not storing the handle.** Uncancellable work. §4.

**8.3 — `Task { }` in `async` code.** You wanted structured concurrency. See §6 of
[[08 - Structured Concurrency]].

**8.4 — Catching `CancellationError` and returning a default.** Turns a correct cancel into a
silent wrong answer. Let it propagate, or handle it *as* cancellation.

**8.5 — `Task.detached` to get off the main actor.** Use `@concurrent nonisolated`.

**8.6 — Checking cancellation between two halves of an atomic operation.** §2.

**8.7 — `Task { }` in `deinit` capturing `self`.** `self` is already being deallocated. Capture
the values you need before the task, or cancel in `deinit` rather than starting work there.

---

## 9. Drill gate

→ **[[Drill 09 - Cancel It Properly]]**

Build the debounced search. Then prove each failure mode: a loop that ignores cancellation and
keeps running; a dropped handle that can't be cancelled; and `.onAppear { Task { } }` firing a
response for a screen you already dismissed.
