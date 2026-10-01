# Drill 13 — Test the Untestable

> Module: [[13 - Testing Concurrent Code]] · How drills work: [[Drills - How They Work]]
> **Time:** ~45 min

---

## Part 1 — Build: a test that catches the reentrancy bug

Go back to the **buggy** `ImageLoader` from [[Drill 04 - The Reentrancy Bug]] — the naive one
that downloads ten times.

Write a test that fails against it:

```swift
@Test func deduplicatesConcurrentLoads() async throws {
    let counter = CallCounter()
    let loader = ImageLoader(download: { key in
        await counter.increment()
        try await Task.sleep(for: .milliseconds(50))
        return Data(key.utf8)
    })

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 { group.addTask { _ = try? await loader.load("cat") } }
    }

    #expect(await counter.count == 1)
}
```

**Watch it fail** (reports 10). Then apply Fix B from drill 04. **Watch it pass.** Then remove
the fix and watch it fail again.

> A test you have not watched fail is not a test. It's a test-shaped thing that might be
> asserting nothing at all.

---

## Part 2 — Break: make a test flaky, then fix it

```swift
// deliberately flaky
@Test func loadsItems() async throws {
    let vm = ViewModel()
    vm.load()                                    // fire and forget
    try await Task.sleep(for: .milliseconds(100))   // 💀 hope
    #expect(vm.items.count == 3)
}
```

Run it 50 times (`swift test --repeat-until-failure`, or a loop). Then run it while the machine
is loaded — build something big in the background. **Watch it fail.**

Fix it by making the work awaitable (expose the `Task` handle, or make `load()` async). Re-run
50 times. Zero failures.

Every `Task.sleep` in a test suite is a future 3am CI failure. This drill is how you learn to
see them as defects rather than as normal.

---

## Part 3 — Control time

Take something that genuinely waits — the debouncer from
[[Drill 09 - Cancel It Properly]] — and make it generic over `Clock`.

Write two tests:
1. With `ContinuousClock`, asserting real behaviour (slow)
2. With a `TestClock`, advancing time manually (instant, deterministic)

Compare the runtime of your suite. Then ask: is the generic-over-`Clock` version *better code*
independent of testing?

<details><summary>Answer</summary>

Yes. It makes "what does this wait on?" an explicit dependency rather than a hidden call to the
global clock. Testability is usually a symptom of good factoring rather than a separate goal —
and this is a clean example of it.
</details>

---

## Part 4 — Cancellation and hangs

**4a** — Write a test proving cancellation actually stops work (not just that
`CancellationError` is thrown). See §6 of the module. Verify it fails against a version that
ignores cancellation.

**4b** — Take the hanging continuation from
[[Drill 07 - Wrap a Delegate]] and write a test with `.timeLimit(.minutes(1))`. Watch it fail
with a timeout rather than hanging your CI forever.

**4c** — Run your whole lab test suite with `-enableThreadSanitizer YES`. Anything it catches
goes straight in the Error Log.

---

## Done when

- [ ] You have a test you watched fail, then pass, then fail again
- [ ] You made a test flake on purpose, then made it deterministic
- [ ] `TestClock` version runs instantly
- [ ] Cancellation test verifies work *stopped*, not just that it threw
- [ ] Suite runs clean under Thread Sanitizer
