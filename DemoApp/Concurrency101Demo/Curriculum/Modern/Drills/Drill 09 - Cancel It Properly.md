# Drill 09 — Cancel It Properly

> Module: [[09 - Tasks, Cancellation and Priority]] · How drills work: [[Drills - How They Work]]
> **Time:** ~45 min

---

## Part 1 — Build: debounced search

In the SwiftUI app, build a search field that:

1. Waits 300ms after the user stops typing before hitting the API
2. Cancels the in-flight request when a new keystroke arrives
3. Never shows results for a stale query
4. Cancels everything when the view disappears

Build it **twice**:

```swift
// A — manual
@MainActor final class SearchModel {
    private var task: Task<Void, Never>?
    func search(_ q: String) { /* your code */ }
}

// B — SwiftUI native
.task(id: query) { await search(query) }
```

Compare them. Which is less code? Which handles view disappearance without you thinking about
it? When would you still need A?

<details><summary>When you'd still need A</summary>

When the task's lifetime isn't the view's lifetime — work that should continue across
navigation, a model shared by several views, or a controller that isn't a view at all.
`.task(id:)` ties lifetime to the view, which is right most of the time and wrong exactly when
you need the work to outlive it.
</details>

---

## Part 2 — Break: three failures

**2a — work that ignores cancellation.**

```swift
func stubborn() async -> Int {
    var total = 0
    for i in 1...50_000_000 { total += i }     // no checks anywhere
    return total
}

let t = Task { await stubborn() }
t.cancel()
print("cancelled!")
```

Time it. The work runs to completion regardless. **Cancellation is a flag, not an interrupt.**

Now add `try Task.checkCancellation()` every 100k iterations and re-run. Measure the
difference in how quickly it actually stops.

**2b — the dropped handle.**

```swift
func fireAndForget() {
    Task { await longRunning() }     // handle discarded
}
```
Try to cancel it. You can't. There is no way to reach it. Store the handle and try again.

**2c — the leaked screen.**

In the SwiftUI app, use `.onAppear { Task { await slowLoad() } }`. Navigate away before it
finishes. Add a print in `slowLoad`'s completion and watch it fire for a screen the user has
already left. Now switch to `.task { }` and watch the same print stop happening.

This is a real bug class — it causes "why did the wrong data appear?" when the response lands
after the user has navigated somewhere else and the model is shared.

---

## Part 3 — The dangerous check

```swift
func transfer(_ amount: Decimal) async throws {
    try Task.checkCancellation()
    try await bank.debit(amount)
    try Task.checkCancellation()     // ⚠️ what happens if cancellation lands HERE?
    try await bank.credit(amount)
}
```

Simulate it: make `debit` and `credit` print, and cancel the task between them
(`Task.sleep` inside `debit` gives you the window).

Money leaves, money never arrives. Now fix it — **two** ways:

1. Remove the middle check and do irreversible work last
2. Make the operation idempotent and retryable, so a partial failure can be resumed

Write down which you'd use for a real payment flow and why.

---

## Part 4 — Task-locals

```swift
enum Trace { @TaskLocal static var id: String? }

await Trace.$id.withValue("req-1") {
    await handler()          // logs should carry req-1
    Task { await handler() } // does this inherit?
    Task.detached { await handler() }  // does this?
}
```

Predict both, then verify.

---

## Done when

- [ ] Both search implementations work; you can say when to use each
- [ ] You watched cancellation get ignored, then fixed it with checks
- [ ] You saw a response arrive for a dismissed screen
- [ ] You lost money in the transfer example and fixed it both ways
- [ ] Task-local inheritance predicted correctly for `Task` and `Task.detached`
