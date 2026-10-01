# GCD Mental Model and Architecture

## What GCD solves

Applications have many kinds of work competing for finite execution resources:

- UI event handling and rendering
- JSON decoding and image processing
- disk and network callbacks
- database and cache coordination
- timers and operating-system events

Creating and coordinating raw threads is difficult. Threads are relatively expensive, their optimal number changes with device load, and manual synchronization easily produces races and deadlocks. Grand Central Dispatch gives the app a **work-queue model**: describe units of work and their constraints, and let the system map them onto execution resources.

```swift
let processingQueue = DispatchQueue(
    label: "com.example.image-processing",
    qos: .userInitiated
)

processingQueue.async {
    let output = processImage(input)

    DispatchQueue.main.async {
        imageView.image = output
    }
}
```

The code states intent:

1. Image processing should not occupy the main queue.
2. Processing belongs to a user-initiated workload.
3. The UI mutation belongs on the main queue.

It does **not** choose or create a particular background thread.

## Queue is not thread

A queue is a logical submission and synchronization context. A thread is an operating-system execution resource.

```text
Work A ─┐
Work B ─┼──> Dispatch queue ──> GCD scheduler ──> system-managed threads
Work C ─┘
```

Except for the main queue, work submitted to one queue may execute on different threads over time. Code should therefore reason in terms of **queue isolation and task ordering**, not thread identity.

Consequences:

- Thread-local storage is not queue-local storage.
- A custom serial queue does not own a permanent thread.
- `Thread.current` is normally a debugging observation, not an API contract.
- A queue label identifies a logical execution context, not a physical thread.

## Work items and closures

In Swift, work is normally expressed as a closure:

```swift
queue.async {
    performWork()
}
```

The queue retains an asynchronously submitted closure until it has executed and can be released. The closure in turn retains strongly captured objects. See [[08 - Memory Management, Closure Capture, and Autorelease Pools]].

For explicit identity, cancellation state, QoS flags, or completion notification, wrap the closure in `DispatchWorkItem`:

```swift
let item = DispatchWorkItem {
    rebuildIndex()
}

item.notify(queue: .main) {
    statusLabel.text = "Complete"
}

workerQueue.async(execute: item)
```

## FIFO: what it does and does not guarantee

Dispatch queues are FIFO submission contexts, but the observable result depends on the queue type.

### Serial queue

For work submitted to one serial queue:

```text
submit A, B, C
execute A, then B, then C
finish  A, then B, then C
```

There is no overlap.

### Concurrent queue

For work submitted to one concurrent queue, earlier items are considered before later items, but multiple items may be executing together. Completion order is not guaranteed:

```text
submitted: A B C
running:   AAAAAA
             BB
              CCCC
finished:     B   C A
```

Do not use a concurrent queue when correctness depends on completion order unless you explicitly add dependencies or synchronization.

## Concurrency versus parallelism

- **Concurrency** means multiple tasks can make progress during overlapping periods.
- **Parallelism** means multiple tasks are literally executing at the same instant on different CPU cores.

A concurrent queue permits concurrency. It does not promise parallel execution. The scheduler may run only one task because of resource constraints, QoS, thermal conditions, or the nature of the workload.

## Asynchrony versus concurrency

These are independent ideas:

- **Asynchronous** describes the relationship to the caller: the caller does not wait.
- **Concurrent** describes the relationship among tasks on a queue: their execution may overlap.

An asynchronous serial queue is extremely common:

```swift
let databaseQueue = DispatchQueue(label: "com.example.database")

databaseQueue.async { saveFirstRecord() }
databaseQueue.async { saveSecondRecord() }
```

The caller continues immediately, but the two saves remain ordered.

## GCD scheduler responsibilities

GCD considers several signals:

- queue serial/concurrent behavior
- quality of service
- barriers and queue hierarchy
- blocked versus runnable work
- available processors and system load
- thermal and energy conditions

The programmer remains responsible for:

- avoiding data races
- choosing appropriate granularity
- not blocking large numbers of workers
- preserving UI responsiveness
- defining ownership and cancellation semantics

GCD schedules work; it does not automatically make unsafe shared data safe.

## Queue hopping has a cost

Every asynchronous submission creates scheduling and capture overhead. Avoid fragmenting tiny operations across many queues merely to appear concurrent.

Poor granularity:

```swift
for value in values {
    queue.async {
        output.append(transform(value)) // also a data race
    }
}
```

Better choices might be:

- process a meaningful batch per work item
- use `concurrentPerform` for suitable CPU-bound loops
- use a task group in Swift concurrency
- remain serial when the collection is small

The performance question is not “Can this be concurrent?” but “Is the work large, independent, safe, and numerous enough to benefit?”

## Relationship to the main run loop

The main queue is drained by the application’s main thread and integrates with its event-processing loop. Long-running main-queue work prevents the app from processing input, layout, drawing, and animations. This is why an app can look frozen without being deadlocked.

Use the main execution context for short UI operations, not expensive computation or blocking waits.

## Key takeaways

1. Submit work to queues; do not manually manage a thread for each task.
2. Queue identity and thread identity are different.
3. FIFO does not mean a concurrent queue finishes in order.
4. Asynchrony controls waiting; concurrency controls overlap.
5. GCD provides scheduling, not automatic data-race prevention.

## Related

- [[02 - Dispatch Queues - Serial, Concurrent, Main, and Global]]
- [[03 - async, sync, Ordering, and Execution Semantics]]
- [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]

## Official references

- [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
- [Dispatch Work Item](https://developer.apple.com/documentation/dispatch/dispatch-work-item)
