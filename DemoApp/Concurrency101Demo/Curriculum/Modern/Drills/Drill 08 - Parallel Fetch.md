# Drill 08 — Parallel Fetch

> Module: [[08 - Structured Concurrency]] · How drills work: [[Drills - How They Work]]
> **Time:** ~45 min · **This drill is about numbers.** Predict every one before running.

---

## Part 1 — Build: three ways, measured

```swift
func fetchOne(_ i: Int) async throws -> Int {
    try await Task.sleep(for: .milliseconds(300))
    return i * 2
}

let ids = Array(1...10)
```

Implement and time all three with `timed(...)` from [[Lab Setup]]:

| Approach | Your prediction | Actual |
| :--- | :--- | :--- |
| Sequential `for` + `await` | | |
| `async let` (first 3 only) | | |
| `withThrowingTaskGroup` (all 10) | | |

<details><summary>What you should see</summary>

Sequential: ~3.0s (10 × 300ms). `async let` with 3: ~300ms. Task group with 10: ~300ms, because
ten sleeping tasks don't need ten threads — they're all suspended, occupying nothing.

If the group came out closer to 3s, check whether your children are main-actor-isolated
(module default!) — main-isolated children serialise on one executor and you get no
concurrency at all. That's the single most instructive way this drill can go "wrong".
</details>

---

## Part 2 — Break: ordering, and the unbounded flood

**2a — completion order.** Make `fetchOne` sleep for `Int.random(in: 100...500)` ms. Collect
results from the group into an array and print it. Predict the order first.

Then fix it so results come back in input order, using the index-carrying pattern from §3.

**2b — the flood.** Change `ids` to `Array(1...5000)` and keep `addTask` in a plain loop. Watch
memory. Now replace the sleep with a real `URLSession` request to a local server or
`httpbin.org/delay/1` and watch requests get throttled, time out, or fail.

Then implement the sliding window from §4 with `maxConcurrent: 6` and re-run. Plot time against
`maxConcurrent` for 1, 2, 6, 20, 100. **There's a knee in that curve** — find it and say why
it's there.

**2c — CPU work.** Replace the sleep with `burnCPU()`. Now run 10 in a task group. Do you get
parallelism?

<details><summary>Answer to 2c</summary>

Only if the children are `nonisolated` — and under Xcode 26 module defaults they may well be
`@MainActor`, in which case all ten serialise on the main thread and the group is slower than a
plain loop (you paid scheduling overhead for nothing).

Mark the work `@concurrent nonisolated` and you'll get roughly `min(10, core count)` speedup.
This is the difference between concurrency and parallelism from §2 of [[01 - Mental Model]],
now with a stopwatch attached.
</details>

---

## Part 3 — See the tree

Profile the task-group version with Instruments' **Swift Concurrency** template. Find the
**Task Forest** and look at the parent/child structure.

Then run a version using `Task { }` in a loop instead of `addTask`, and compare the forests.
The structured one is a tree; the unstructured one is a scattering of orphans. Screenshot both
and put them in your notes — this picture explains structured concurrency better than any
paragraph.

---

## Done when

- [ ] Three timings predicted and measured, and you can explain each number
- [ ] Ordering bug produced and fixed with the index pattern
- [ ] Concurrency limiter implemented; you found the knee in the curve
- [ ] CPU-bound case tried, and you know why it did or didn't parallelise
- [ ] Both Task Forests compared in Instruments
