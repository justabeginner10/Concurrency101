# `async`, `sync`, Ordering, and Execution Semantics

Queue type and submission method answer different questions:

| Dimension | Question |
|---|---|
| Serial vs concurrent | May tasks on this queue overlap? |
| `async` vs `sync` | Must the caller wait for this submitted task? |

## Asynchronous submission

```swift
queue.async {
    performWork()
}

continueImmediately()
```

`async` enqueues the closure and returns. It does not guarantee:

- immediate start
- another physical thread
- parallel execution
- completion before the surrounding function returns

### Example

```swift
let queue = DispatchQueue(label: "com.example.serial")

print("1")

queue.async {
    print("3")
}

print("2")
```

The caller prints `1`, submits the task, and prints `2` without waiting. The queued print is
not waited for — it often appears after `2`, but it may already be running on another thread.
Do not treat `1-2-3` as a guarantee. In a real multithreaded program, exact interleaving with
unrelated queues is not generally guaranteed, so correctness should never depend on print
timing.

### Asynchronous serial work

```swift
queue.async { stepOne() }
queue.async { stepTwo() }
queue.async { stepThree() }
```

The caller does not wait, but a serial queue preserves step ordering.

## Synchronous submission

```swift
let result = queue.sync {
    calculateResult()
}
```

`sync` blocks the calling thread until the submitted work finishes, then returns the closure’s value or rethrows its error.

```swift
let snapshot: [Record] = stateQueue.sync {
    records
}
```

This is useful for short reads from queue-isolated state. It is dangerous when:

- called from the same serial queue
- called from the main queue for slow work
- locks or other synchronous queue calls form a dependency cycle
- the submitted work waits for the caller

### `sync` does not mean background

```swift
DispatchQueue.global(qos: .utility).sync {
    slowExport()
}
```

If the main thread calls this, the main thread remains blocked until the export finishes. The destination queue does not make the caller responsive.

### `sync` does not necessarily mean a thread switch

GCD may optimize synchronous execution. The API promises logical execution with the queue’s synchronization semantics and a blocked caller; it does not promise a physical hop to a particular worker thread.

## The four combinations

### Serial + async

```swift
serialQueue.async { mutateStateA() }
serialQueue.async { mutateStateB() }
```

- caller does not wait
- A and B do not overlap
- useful for ordered mutation

### Serial + sync

```swift
let value = serialQueue.sync { readState() }
```

- caller waits
- exclusive with other work on that queue
- useful for short synchronous snapshots
- deadlocks if called reentrantly from the same serial queue

### Concurrent + async

```swift
concurrentQueue.async { independentA() }
concurrentQueue.async { independentB() }
```

- caller does not wait
- A and B may overlap
- typical independent background work

### Concurrent + sync

```swift
let value = concurrentQueue.sync { compute() }
```

- caller waits
- the item may overlap with ordinary work on the concurrent queue
- does not create mutual exclusion by itself

## Main queue ordering

Calling `DispatchQueue.main.async` while already on the main queue defers the closure:

```swift
print("A")

DispatchQueue.main.async {
    print("C")
}

print("B")
```

The current main-queue item must return before the newly enqueued item can run, producing A–B–C for this sequence.

This technique can break a call stack or defer work to a later run-loop opportunity, but repeatedly dispatching to main to hide ordering problems can make code unpredictable. Prefer explicit state and structured flow.

## Same-queue deadlock

```swift
let queue = DispatchQueue(label: "com.example.serial")

queue.async {
    queue.sync {
        print("unreachable")
    }
}
```

Reasoning:

1. The outer item occupies the serial queue.
2. It enqueues an inner item and waits for it.
3. The inner item cannot start until the outer item leaves.
4. The outer item cannot leave until the inner item finishes.

Never synchronously dispatch onto a serial queue that may already be in the current execution chain.

The most famous example is:

```swift
DispatchQueue.main.sync {
    updateUI()
}
```

This deadlocks when called from the main queue.

## Cross-queue deadlock

```swift
queueA.sync {
    queueB.sync {
        queueA.sync {
            // Circular wait
        }
    }
}
```

Even individually reasonable synchronous calls become unsafe when their dependency graph contains a cycle. Library code should be especially cautious: it may not know the caller’s current queue.

## Reentrancy

Reentrancy means a component is entered again before an earlier invocation finishes. A common but delicate “sync if outside, direct if inside” pattern uses queue-specific data:

```swift
final class Store {
    private let queue = DispatchQueue(label: "com.example.store")
    private let key = DispatchSpecificKey<Void>()
    private var values: [String] = []

    init() {
        queue.setSpecific(key: key, value: ())
    }

    private func withIsolation<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: key) != nil {
            return try body()
        }

        return try queue.sync(execute: body)
    }
}
```

This avoids a specific self-deadlock but also permits reentrant access, which may violate higher-level invariants. Prefer APIs with clear isolation boundaries rather than using this pattern casually.

## `asyncAfter`

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
    showHint()
}
```

The deadline is the earliest eligibility time, not an exact execution appointment. If the main queue is occupied, the closure runs later.

`asyncAfter` does not sleep or reserve a worker thread while waiting. Use a monotonic `DispatchTime` for elapsed-time delays. `DispatchWallTime` follows wall-clock time and is relevant when behavior should track clock/calendar changes.

## Blocking versus suspension

GCD’s `sync`, `DispatchGroup.wait()`, and `DispatchSemaphore.wait()` block a thread. Swift concurrency’s `await` normally suspends a task and frees the underlying thread to run other work. This difference is one reason modern async code should avoid wrapping asynchronous APIs in semaphore waits.

## Practical rules

1. Prefer `async` for potentially slow work.
2. Keep synchronous critical sections short.
3. Never use `main.sync` unless you can prove the caller is not on the main queue; API designs that require this are usually brittle.
4. Avoid synchronous calls between components with different private queues.
5. Do not treat timing observed in logs as a scheduling guarantee.
6. Compose completion asynchronously instead of blocking when possible.

## Related

- [[02 - Dispatch Queues - Serial, Concurrent, Main, and Global]]
- [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]

## Official reference

- [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
