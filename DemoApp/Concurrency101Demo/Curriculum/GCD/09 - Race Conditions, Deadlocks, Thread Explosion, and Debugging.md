# Race Conditions, Deadlocks, Thread Explosion, and Debugging

## Data race

A data race occurs when multiple execution contexts access the same memory concurrently, at least one access writes, and synchronization is insufficient.

```swift
var values: [Int] = []

DispatchQueue.global().async { values.append(1) }
DispatchQueue.global().async { values.append(2) }
```

Swift collections do not support unsynchronized concurrent mutation. Outcomes include wrong results, memory corruption, or crashes.

Fix by choosing one isolation domain:

- actor
- serial queue
- custom concurrent queue with barriers
- suitable lock

Do not “fix” a race with sleeps, priorities, or assumptions based on observed log order.

## Race condition versus data race

A **data race** is unsynchronized conflicting memory access. A broader **race condition** is behavior whose correctness depends on timing, even when each individual access is technically synchronized.

Example check-then-act race:

```swift
if cache.contains(key) {       // synchronized internally
    cache.remove(key)          // synchronized internally
}
```

Another task may modify the cache between calls. The whole operation must be atomic at the abstraction level.

## Deadlock

A deadlock is a cycle of dependencies in which no participant can proceed.

### Same serial queue

```swift
queue.async {
    queue.sync {
        // Cannot start until outer block finishes.
    }
}
```

### Main queue

```swift
DispatchQueue.main.sync {
    // Deadlocks if caller is already executing on main queue.
}
```

### Queue and lock cycle

```text
Queue A owns Lock X and synchronously waits for Queue B
Queue B needs Lock X before it can finish
```

Deadlocks are dependency-graph problems. The participating primitives do not need to be the same kind.

## Livelock and starvation

- **Livelock:** participants keep reacting and changing state but make no useful progress.
- **Starvation:** work remains ready but repeatedly fails to receive the resources it needs.

Examples include aggressive retry loops, unfair resource competition, or low-QoS work holding a resource required by high-QoS work.

## Thread explosion

When work on concurrent queues blocks, the system may create more worker threads so other submitted work can progress. If many tasks block, thread count and memory overhead can grow until performance collapses.

Risky pattern:

```swift
for operation in thousandsOfOperations {
    DispatchQueue.global().async {
        semaphore.wait() // Most blocks may occupy waiting threads.
        defer { semaphore.signal() }
        performBlockingOperation(operation)
    }
}
```

Each blocked thread consumes stack memory and scheduler attention. More threads do not create more CPU cores.

Prefer:

- genuinely asynchronous I/O APIs
- structured concurrency, where `await` suspends tasks
- bounded submission rather than submit-everything-then-block
- `OperationQueue.maxConcurrentOperationCount` for suitable legacy designs
- small numbers of meaningful CPU-bound work items

## Main-thread blocking

The following can freeze the interface:

```swift
group.wait()
semaphore.wait()
backgroundQueue.sync { slowWork() }
Thread.sleep(forTimeInterval: 2)
```

The fact that a destination is called “background” is irrelevant: a synchronous main-thread caller still waits.

## Priority inversion

High-priority work waiting on a resource held by low-priority work creates inversion. Avoid long critical sections, inaccurate QoS, and synchronous cross-QoS dependencies.

## Debugging queue problems

### Use meaningful labels

```swift
let queue = DispatchQueue(
    label: "com.example.account-store.isolation"
)
```

Labels appear in debugger and performance tools.

### Assert queue assumptions

```swift
dispatchPrecondition(condition: .onQueue(.main))
dispatchPrecondition(condition: .notOnQueue(workerQueue))
```

For a barrier-only mutation helper:

```swift
dispatchPrecondition(condition: .onQueueAsBarrier(isolationQueue))
```

Assertions diagnose incorrect call paths; they do not provide isolation.

### Thread Sanitizer

Enable Thread Sanitizer in the Xcode scheme diagnostics when testing. It can detect many data races and synchronization mistakes. Limitations:

- it cannot prove the absence of races
- timing changes can hide or expose bugs
- it increases execution overhead
- logical races involving correctly synchronized but wrongly ordered operations may not be detected

### Main Thread Checker

Main Thread Checker identifies many invalid UI calls from background execution contexts. It complements, rather than replaces, correct `MainActor` or main-queue isolation.

### Instruments

Use Instruments to inspect:

- thread counts and blocked threads
- CPU utilization
- signposts and intervals
- queue activity
- contention and long-running work
- hangs and main-thread stalls

Measure before assuming dispatch improves performance.

### Xcode debugger

When paused or hung:

1. inspect all thread backtraces
2. look for `dispatch_sync`, semaphore waits, group waits, and locks
3. identify which queue/resource each waiter needs
4. find the cycle or unavailable signal

A single blocked stack is rarely enough; deadlock diagnosis requires viewing the dependency graph.

## Logging without creating assumptions

```swift
import os

let logger = Logger(subsystem: "com.example.app", category: "indexing")

queue.async {
    logger.debug("Indexing started")
    rebuildIndex()
    logger.debug("Indexing ended")
}
```

Logs help reveal behavior, but adding logs changes timing. Never convert one observed ordering into an undocumented guarantee.

## Failure-prevention checklist

- All mutable state has one explicit isolation owner.
- No `sync` call can target the current serial queue.
- The main thread never waits for slow or externally controlled work.
- Every group `enter()` has one `leave()`.
- Every semaphore acquisition releases via `defer`.
- No unbounded collection of tasks blocks worker threads.
- QoS reflects user intent.
- Cancellation and timeout semantics are explicit.
- Queue labels are meaningful.
- Thread Sanitizer is exercised during development.

## Official references

- [DispatchQueue: avoiding excessive thread creation](https://developer.apple.com/documentation/dispatch/dispatchqueue)
- [dispatchPrecondition](https://developer.apple.com/documentation/dispatch/dispatchprecondition(condition:))

