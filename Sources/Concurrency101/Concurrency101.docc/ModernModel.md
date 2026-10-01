# Mental model (Swift Concurrency)

@Metadata {
    @TitleHeading("Article")
}

Swift Concurrency is a **task scheduler with isolation in the type system**. You write `async` functions. The system runs *tasks*, not threads you own.

A task is not a thread. `await` is not `sync`.

## Two axes

| Axis | Swift words | Concurrency101.Modern words |
|---|---|---|
| Isolation | actor / `@MainActor` / nonisolated | `ExclusiveState` / `waitForUI` / `runDetachedFromCaller` |
| Waiting | `await` vs unstructured `Task { }` | suspend this task vs start and return |

``Concurrency101/Modern/waitForUI(_:)`` is `await MainActor.run`: the *task* waits, the *thread* is free. ``Concurrency101/Modern/updateUI(_:)`` is `Task { @MainActor in }`: the caller does not wait.

``Concurrency101/Modern/Blocking/parkThisThreadUntilTaskFinishes(_:)`` parks the thread. That is the anti-pattern. See <doc:Blocking>.

## Isolation rule

Shared mutable state needs one owner. In Swift Concurrency that is an `actor` or `@MainActor`, not a queue you remember to use. ``Concurrency101/Modern/ExclusiveState`` is a teaching actor.

At every `await` *inside* an actor method, other callers of that actor may run. Isolation is serial between suspension points, not across them. That is reentrancy.

## Structured vs unstructured

`async let` and `withTaskGroup` (``Concurrency101/Modern/runTwoAtOnce(_:_:)``, ``Concurrency101/Modern/runSeveralThenContinue(jobs:then:)``) are structured: children cannot outlive the `await`.

`Task { }` and `Task.detached` are unstructured: they escape the scope. You almost never want `Task.detached`. Created from `@MainActor`, `Task { }` **stays** on the main actor.

## Cancellation

`cancel()` sets a flag. `Task.sleep` checks it. A CPU loop does not. See ``Concurrency101/Modern/makeCancellableWork(_:)``.

## Official references

- [Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Task](https://developer.apple.com/documentation/swift/task)
