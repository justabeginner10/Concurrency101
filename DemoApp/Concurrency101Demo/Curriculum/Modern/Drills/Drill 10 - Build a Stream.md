# Drill 10 — Build a Stream

> Module: [[10 - AsyncSequence and AsyncStream]] · How drills work: [[Drills - How They Work]]
> **Time:** ~40 min

---

## Part 1 — Build: a timer stream

```swift
func ticks(every interval: Duration) -> AsyncStream<Int> {
    // your implementation
}

for await tick in ticks(every: .milliseconds(200)).prefix(5) {
    print(tick)
}
```

Requirements: yields 1, 2, 3…; `onTermination` invalidates the timer; `prefix(5)` ends it
cleanly.

---

## Part 2 — Break: three behaviours you need to see

**2a — the leak.** Delete `onTermination`. Add a print inside the timer body. Break out of the
loop after 3 ticks. **The timer keeps printing forever.** That's the leak, and in a real app
it's a location manager or a socket instead of a print.

**2b — two consumers.** Attach two `for await` loops to the *same* stream:

```swift
let stream = ticks(every: .milliseconds(200))
async let a: () = { for await t in stream { print("A: \(t)") } }()
async let b: () = { for await t in stream { print("B: \(t)") } }()
_ = await (a, b)
```

Predict the output first. Does each get every value?

<details><summary>Answer</summary>

No. `AsyncStream` is **unicast** — the values are split arbitrarily between the two consumers.
A gets some, B gets others, neither gets all. This is the biggest behavioural difference from
Combine and it catches everyone exactly once.

Fix: give each consumer its own stream from a shared producer (the `Broadcaster` actor in §5 of
the module), or use `AsyncChannel` from swift-async-algorithms.
</details>

**2c — buffering.** Make the producer yield every 10ms and the consumer take 500ms per
iteration. Run with `.unbounded`, then `.bufferingNewest(1)`, then `.bufferingOldest(5)`.
Print what the consumer sees in each case, and watch memory in the unbounded version.

Which would you pick for: GPS coordinates? A chat message feed? A progress percentage?

<details><summary>Answers</summary>

GPS → `.bufferingNewest(1)`: you only care where you are *now*.
Chat messages → `.bufferingOldest(n)` or unbounded with a real cap: dropping messages is a
correctness bug, and order matters.
Progress → `.bufferingNewest(1)`: intermediate percentages are worthless.
</details>

---

## Part 3 — Build a broadcaster

Implement the multicast `Broadcaster` actor from §5 of the module. Requirements:

- Multiple subscribers each get **every** event
- A subscriber that goes away is cleaned up (test this — subscribe, drop, broadcast, confirm no
  growth in the continuations dictionary)
- Broadcasting with zero subscribers doesn't crash or leak

---

## Part 4 — Operators

Add `swift-async-algorithms` and rebuild the debounced search from
[[Drill 09 - Cancel It Properly]] using `.debounce(for:)` over an `AsyncStream` of keystrokes
instead of manual task cancellation.

Compare the three implementations you now have (manual `Task`, `.task(id:)`, `.debounce`).
Which reads best? Which would you put in a codebase other people maintain?

---

## Done when

- [ ] Timer stream works with cleanup
- [ ] You saw the leak with `onTermination` removed
- [ ] You saw two consumers split values, and fixed it with a broadcaster
- [ ] All three buffering policies observed, with a reasoned choice for each scenario
- [ ] Debounce implemented with async-algorithms
