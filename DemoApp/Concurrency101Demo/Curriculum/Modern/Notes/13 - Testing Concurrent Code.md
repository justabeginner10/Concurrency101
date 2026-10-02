# Module 13 — Testing Concurrent Code

> Terms: [[Glossary]] · Prev: [[12 - Migrating to Swift 6]]
> **Goal:** async tests that fail for real reasons and never flake.
> Drill: [[Drill 13 - Test the Untestable]]

---

## 1. Async tests are the easy part

```swift
import Testing

@Test func fetchesUser() async throws {
    let client = APIClient(session: .mock)
    let user = try await client.fetchUser(id: "1")
    #expect(user.name == "Ada")
}
```

Swift Testing handles `async` natively — no expectations, no waiting, no `XCTestExpectation`
bookkeeping. The `await` *is* the synchronisation.

Isolation works as you'd expect:

```swift
@Test @MainActor func updatesViewModel() async {
    let vm = ProfileViewModel()        // @MainActor type — test must be too
    await vm.load()
    #expect(vm.profile != nil)
}
```

The hard part isn't writing async tests. It's writing async tests that are **deterministic**.

---

## 2. The flakiness rule

> **Never `sleep` to wait for something. Await the thing itself.**

```swift
// ❌ flaky: passes on your Mac, fails in CI under load
@Test func loads() async throws {
    vm.load()
    try await Task.sleep(for: .milliseconds(100))
    #expect(vm.items.count == 3)
}

// ✅ deterministic
@Test func loads() async throws {
    await vm.load()                    // make it awaitable
    #expect(vm.items.count == 3)
}
```

If you can't await it, the API is untestable and that's a design problem, not a test problem.
The fix is to expose the task:

```swift
@MainActor
final class ViewModel {
    private(set) var loadTask: Task<Void, Never>?
    func load() { loadTask = Task { ... } }
}

// test
vm.load()
await vm.loadTask?.value        // now deterministic
```

Every `Task.sleep` in a test suite is a future flaky failure with a timer on it. Treat them as
defects.

---

## 3. `confirmation` — for callbacks and streams

The replacement for `XCTestExpectation`:

```swift
@Test func emitsThreeValues() async throws {
    await confirmation(expectedCount: 3) { confirm in
        for await _ in provider.ticks.prefix(3) {
            confirm()
        }
    }
}
```

It also asserts the *negative*, which `XCTestExpectation` made awkward:

```swift
@Test func doesNotEmitAfterCancel() async throws {
    await confirmation(expectedCount: 0) { confirm in
        let task = Task { for await _ in stream { confirm() } }
        task.cancel()
        try? await Task.sleep(for: .milliseconds(50))
    }
}
```

---

## 4. Controlling time

Code that waits is untestable unless time is injectable. Inject a `Clock`:

```swift
struct Debouncer<C: Clock> {
    let clock: C
    let delay: C.Duration

    func run(_ work: @Sendable () async -> Void) async throws {
        try await clock.sleep(for: delay)
        await work()
    }
}

// production
Debouncer(clock: ContinuousClock(), delay: .milliseconds(300))

// test — no real waiting, no flakiness
let test = TestClock()
let debouncer = Debouncer(clock: test, delay: .milliseconds(300))
Task { try await debouncer.run { ... } }
await test.advance(by: .milliseconds(300))     // time moves because you said so
```

`TestClock` isn't in the standard library — it's in
[swift-clocks](https://github.com/pointfreeco/swift-clocks), and it's worth the dependency.
The generic-over-`Clock` shape is good design independent of testing: it makes "what does this
wait on?" an explicit parameter.

---

## 5. Testing actors

Actors test naturally — `await` does the work:

```swift
@Test func deduplicatesConcurrentLoads() async throws {
    let counter = CallCounter()
    let loader = ImageLoader(download: { url in
        await counter.increment()
        try await Task.sleep(for: .milliseconds(50))
        return Data()
    })

    // fire ten concurrent loads of the same URL
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask { _ = try? await loader.load(url) }
        }
    }

    #expect(await counter.count == 1)     // the reentrancy fix from module 04, verified
}
```

This is the shape worth learning: **a test that would fail against the buggy version.** Write
it against the §4.1 buggy `ImageLoader` from [[04 - Actors]] first, watch it report 10, then
fix the actor and watch it report 1. That's a regression test with a proven failure mode,
which is the only kind worth having.

---

## 6. Testing cancellation

```swift
@Test func stopsWorkWhenCancelled() async throws {
    let progress = Progress()
    let task = Task { try await longRunning(reporting: progress) }

    while await progress.completed < 2 { await Task.yield() }   // wait for real progress
    task.cancel()

    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(await progress.completed < 10)      // it stopped early
}
```

Both halves matter: the error propagated **and** the work actually stopped. A cancellation test
that only checks for `CancellationError` passes against code that ignores cancellation
completely and throws at the end.

---

## 7. Serialisation and shared state

Swift Testing runs tests **in parallel by default**. Tests sharing global state will interfere:

```swift
@Suite(.serialized)
struct DatabaseTests { }          // run one at a time

@Test(.timeLimit(.minutes(1)))
func doesNotHang() async { }      // catches continuation leaks
```

The time limit is the practical defence against the "resumed zero times" bug from §2 of
[[07 - Bridging Legacy Code]] — without it, a leaked continuation hangs CI instead of failing
a test.

Better than `.serialized`, where you can manage it: give each test its own instance. Parallel
tests are fast tests, and shared mutable state in a test suite is the same design smell as
anywhere else.

---

## 8. Thread Sanitizer in CI

```bash
xcodebuild test \
  -scheme MyApp \
  -enableThreadSanitizer YES \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Slow (5–15×), so run it nightly rather than per-PR. It's the only thing that catches races you
smuggled past the compiler with `@unchecked Sendable`, `nonisolated(unsafe)`, or a C library —
which is exactly the set of places races still live in a Swift 6 codebase.

---

## 9. Pitfalls

**9.1 — `Task.sleep` as synchronisation.** §2. The leading cause of flaky suites.

**9.2 — Testing implementation, not behaviour.** "Does it hop to a background thread" is not a
requirement. "Does the UI stay responsive" is.

**9.3 — Not testing the concurrent case at all.** One caller always passes. The reentrancy bug
only shows up with ten. §5.

**9.4 — Forgetting a time limit.** A hung test is indistinguishable from a slow one until CI
times out at 40 minutes.

**9.5 — `@MainActor` on every test out of habit.** It serialises them onto one executor and
hides isolation bugs that would otherwise surface.

**9.6 — Assuming a passing test means no races.** It means no race *occurred that run*. TSan is
the tool that actually looks.

---

## 10. Drill gate

→ **[[Drill 13 - Test the Untestable]]**

Take the buggy `ImageLoader` from [[04 - Actors]], write a test that fails against it, fix the
actor, watch it pass. Then remove the fix and confirm it fails again. **A test you have not
watched fail is not a test.**
