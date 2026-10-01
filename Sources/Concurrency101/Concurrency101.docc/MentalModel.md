# Mental model (GCD)

@Metadata {
    @TitleHeading("Article")
}

Grand Central Dispatch is a **work scheduler**. You submit closures to queues. The system decides when and on which threads to run them.

A queue is an ordering and isolation mechanism — **not a thread**.

## Two axes

| Axis | GCD words | Concurrency101.GCD words |
|---|---|---|
| Overlap | serial vs concurrent queue | private serial lane vs shared concurrent lane |
| Waiting | `async` vs `sync` | run and return vs block this thread |

``Concurrency101/GCD/runOnLane(_:_:)`` is always `async`: the caller continues. ``Concurrency101/GCD/Blocking/blockThisThreadUntilFinished(on:_:)`` is `sync`: this thread parks.

Those questions are independent. You can `async` onto a serial lane (no wait, no overlap). You can `sync` onto a concurrent lane (wait, overlap still possible for *other* items).

## UI rule

If it touches the screen, it belongs on the main queue: ``Concurrency101/GCD/updateUI(_:)``. That is GCD `DispatchQueue.main.async` and Swift Concurrency `@MainActor`.

## Isolation rule

Shared mutable state needs one owner. In GCD that is often ``Concurrency101/GCD/makePrivateSerialLane(label:qos:)``. In Swift Concurrency it is an `actor` — see <doc:ModernModel>.

Submitting two `runUserRequestedWork` closures that both increment `count` is a data race. Global queues are concurrent and shared.

## Official references

- [Dispatch](https://developer.apple.com/documentation/dispatch)
- [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
