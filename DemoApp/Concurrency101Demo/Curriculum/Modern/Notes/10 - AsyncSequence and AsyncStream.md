# Module 10 — AsyncSequence and AsyncStream

> Roadmap: [[00 - Roadmap]] · Terms: [[Glossary]] · Prev: [[09 - Tasks, Cancellation and Priority]] ·
> Next: [[11 - Swift 6.2 and Modern Defaults]]
> **Goal:** model values arriving over time without reaching for Combine.
> Drill: [[Drill 10 - Build a Stream]]

---

## 1. `AsyncSequence` is `Sequence` with `await`

```swift
for await value in someAsyncSequence { }
for try await value in someThrowingAsyncSequence { }
```

Each iteration can suspend. That's the entire idea.

Already available in the SDK:

```swift
for await note in NotificationCenter.default.notifications(named: .x) { }
for try await line in url.lines { }
for try await byte in url.resourceBytes { }
for await value in combinePublisher.values { }
for await update in observationTracking { }
```

The loop is cancellation-aware: cancelling the task ends the iteration. And `break` terminates
the sequence, triggering cleanup — which is what `onTermination` (§3) hooks.

---

## 2. `AsyncStream` — turning callbacks into a sequence

Two ways to build one. The modern form separates construction from production:

```swift
let (stream, continuation) = AsyncStream.makeStream(of: Int.self)

// producer — anywhere, any thread
continuation.yield(1)
continuation.yield(2)
continuation.finish()

// consumer
for await n in stream { print(n) }
```

The closure form, for when the source's lifetime matches the stream's:

```swift
var ticks: AsyncStream<Date> {
    AsyncStream { continuation in
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            continuation.yield(Date())
        }
        continuation.onTermination = { @Sendable _ in
            timer.invalidate()          // ← the line everyone forgets
        }
    }
}
```

`AsyncThrowingStream` is the same with `continuation.finish(throwing:)`.

---

## 3. `onTermination` — the part that leaks if you skip it

It fires when:

- the producer calls `finish()`
- the consumer `break`s out of the loop
- the consuming task is **cancelled**
- the stream is deallocated

Whatever resource you started in the stream's construction — a timer, a location manager, a
socket, a delegate registration — must be torn down here. This is the `AsyncStream` equivalent
of `AnyCancellable`, and omitting it is the single most common `AsyncStream` bug.

`onTermination` is `@Sendable` and runs in no particular isolation, so capture a `Sendable`
handle rather than `self`.

---

## 4. Buffering — what happens when nobody's listening

```swift
AsyncStream(bufferingPolicy: .bufferingNewest(10)) { c in ... }
```

| Policy | Behaviour | Use for |
| :--- | :--- | :--- |
| `.unbounded` (default) | Keep everything | ⚠️ unbounded memory if the producer outpaces the consumer |
| `.bufferingNewest(n)` | Keep the n most recent, drop old | Live state: location, sensor, prices |
| `.bufferingOldest(n)` | Keep the first n, drop new | Event logs where order of arrival matters |

**The default is `.unbounded`, and it's rarely what you want** for a hot producer. A location
stream whose consumer stalls for ten seconds will happily buffer every update. Pick a policy
deliberately; `.bufferingNewest(1)` is right for "I only care about the current value."

`continuation.yield()` returns a `YieldResult` telling you whether the value was enqueued,
dropped, or the stream had terminated — worth checking in a producer that can back off.

---

## 5. ⚠️ One consumer only

`AsyncStream` is **unicast**. Two `for await` loops over the same stream split the values
arbitrarily between them; they do not each get everything.

This is the biggest behavioural difference from Combine, and the one that catches people
migrating. If you need multicast:

- Give each consumer its **own** stream from the same producer (keep an array of continuations)
- Or use `AsyncChannel` / `share()`-style operators from
  [swift-async-algorithms](https://github.com/apple/swift-async-algorithms)
- Or use `@Observable` — for UI state, observation is usually the better model than a stream

```swift
// multicast by hand
actor Broadcaster {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    func subscribe() -> AsyncStream<Event> {
        let id = UUID()
        let (stream, c) = AsyncStream.makeStream(of: Event.self)
        continuations[id] = c
        c.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id) }
        }
        return stream
    }

    private func unsubscribe(_ id: UUID) { continuations[id] = nil }
    func broadcast(_ event: Event) { continuations.values.forEach { $0.yield(event) } }
}
```

---

## 6. Operators

The standard library gives you `map`, `filter`, `compactMap`, `prefix`, `dropFirst`,
`reduce` — lazy, applied as values arrive:

```swift
for await name in users.map(\.name).filter({ !$0.isEmpty }).prefix(10) { }
```

For anything richer, add **swift-async-algorithms**:

```swift
import AsyncAlgorithms

for await query in searchInput.debounce(for: .milliseconds(300)) { }
for await (a, b) in zip(streamA, streamB) { }
for await v in merge(streamA, streamB) { }
for await batch in events.chunked(by: .repeating(every: .seconds(1))) { }
```

`debounce`, `throttle`, `merge`, `zip`, `combineLatest`, `chunked` — the Combine operator
vocabulary, for `AsyncSequence`. If you're migrating off Combine, this package is the missing
piece and is worth adopting early.

---

## 7. Writing your own `AsyncSequence`

Usually unnecessary — `AsyncStream` covers most cases. When you do need one:

```swift
struct Countdown: AsyncSequence {
    typealias Element = Int
    let start: Int

    struct Iterator: AsyncIteratorProtocol {
        var current: Int
        mutating func next() async -> Int? {
            guard current > 0, !Task.isCancelled else { return nil }
            try? await Task.sleep(for: .milliseconds(500))
            defer { current -= 1 }
            return current
        }
    }
    func makeAsyncIterator() -> Iterator { Iterator(current: start) }
}
```

Note the `Task.isCancelled` check — a custom iterator is *your* loop, so cancellation
awareness is your job. Returning `nil` ends the sequence cleanly.

---

## 8. `AsyncStream` vs Combine

| | `AsyncStream` | Combine |
| :--- | :--- | :--- |
| Consumers | One | Many |
| Cancellation | Task cancellation | `AnyCancellable` |
| Buffering | Buffering / dropping policy (not Combine-style demand) | Demand-based |
| Error typing | Throws or not | Typed `Failure` |
| Operators | stdlib + async-algorithms | Rich, built in |
| Future | ✅ the direction Apple is going | Maintained, not evolving |

Use `AsyncStream` for new work. Keep Combine where it's already load-bearing and multicast;
bridge with `.values` when you want to consume a publisher from async code. Don't rewrite
working Combine code purely for fashion — but don't start new streams there either.

For **UI state specifically**, `@Observable` has largely replaced both. Streams are for events;
observation is for state. Confusing the two produces a lot of unnecessary machinery.

---

## 9. Pitfalls

**9.1 — Forgetting `onTermination`.** Leaks the underlying resource. §3.

**9.2 — Two consumers on one stream.** Values split, not duplicated. §5.

**9.3 — Unbounded buffering on a hot producer.** Memory growth that looks like a leak. §4.

**9.4 — A `for await` loop that never ends.** It holds the task alive forever. Make sure the
producer calls `finish()`, or the consumer `break`s, or the task gets cancelled.

**9.5 — Heavy work inside the loop body.** A custom `AsyncSequence` is pull-based: a slow
`next()` does stall the producer. `AsyncStream` is different — default `.unbounded` buffering
lets the producer keep yielding; a slow `for await` grows memory, it does not throttle. Hand
CPU work to a task group or `@concurrent` helper rather than hoping the stream will wait.

**9.6 — Using a stream where you wanted state.** If consumers care about "the current value"
rather than "every change", you want `@Observable` or an actor property.

---

## 10. Drill gate

→ **[[Drill 10 - Build a Stream]]**

Wrap a timer as an `AsyncStream` with working `onTermination`; prove the leak by removing it.
Then attach two consumers and watch the values split — the behaviour that surprises everyone
exactly once.
