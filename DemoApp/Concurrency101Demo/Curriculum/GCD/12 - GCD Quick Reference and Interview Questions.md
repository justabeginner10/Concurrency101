# GCD Quick Reference and Interview Questions

## Queue creation

```swift
// Custom serial queue
let serial = DispatchQueue(label: "com.example.serial")

// Custom concurrent queue
let concurrent = DispatchQueue(
    label: "com.example.concurrent",
    qos: .userInitiated,
    attributes: .concurrent
)

// System queues
let main = DispatchQueue.main
let global = DispatchQueue.global(qos: .utility)
```

## Submission

```swift
queue.async {
    // Caller continues without waiting.
}

let result = queue.sync {
    // Caller blocks; closure may return a value.
}

queue.asyncAfter(deadline: .now() + .seconds(1)) {
    // Eligible after approximately one second.
}
```

## Barrier isolation

```swift
let stateQueue = DispatchQueue(
    label: "com.example.state",
    attributes: .concurrent
)

let snapshot = stateQueue.sync {
    state
}

stateQueue.async(flags: .barrier) {
    state = newState
}
```

Use the barrier pattern only with a custom concurrent queue you control.

## Group

```swift
let group = DispatchGroup()

queue.async(group: group) { taskA() }
queue.async(group: group) { taskB() }

group.notify(queue: .main) {
    allFinished()
}
```

Callback membership:

```swift
group.enter()
startAsyncOperation {
    defer { group.leave() }
    handleCompletion()
}
```

## Semaphore

```swift
let semaphore = DispatchSemaphore(value: 2)

semaphore.wait()
defer { semaphore.signal() }
useLimitedResource()
```

`wait()` blocks a thread. Do not use semaphores as a casual bridge from async code to synchronous code.

## Work item

```swift
let item = DispatchWorkItem {
    performWork()
}

item.notify(queue: .main) {
    finished()
}

queue.async(execute: item)
item.cancel() // Cooperative cancellation intent
```

## Queue correctness laws

1. Queue is not thread.
2. `async` is not the same as concurrent.
3. `sync` is not the same as serial.
4. A serial queue protects state only when all access uses that queue.
5. A concurrent queue does not guarantee completion order.
6. QoS is intent, not a deadline or correctness tool.
7. `sync` to the same serial queue deadlocks.
8. Main-thread blocking freezes UI even if work targets a background queue.
9. Work-item cancellation is cooperative.
10. Group/semaphore timeout does not cancel underlying work.
11. A barrier needs a private concurrent queue for reader/writer isolation.
12. Many blocking concurrent tasks can cause thread explosion.

## Interview questions

### What is GCD?

GCD is Apple’s system-managed mechanism for scheduling work items onto dispatch queues. It manages the underlying worker threads according to queue constraints, QoS, and system resources.

### What is the difference between a queue and a thread?

A queue is a logical ordering and scheduling context. A thread is an execution resource. Except for the main queue, a queue is not permanently bound to one thread.

### Serial versus concurrent queue?

A serial queue permits one of its items to execute at a time. A concurrent queue permits overlap. Independent serial queues can still execute concurrently with each other.

### `async` versus `sync`?

`async` submits and returns without waiting. `sync` blocks the caller until the item completes and can return its result. This choice is independent of whether the target queue is serial or concurrent.

### Why does `DispatchQueue.main.sync` deadlock?

When called from the main queue, the current item waits for a newly submitted main-queue item, but the serial main queue cannot begin that item until the current one finishes.

### Does dispatching synchronously to a background queue keep UI responsive?

No. If the main thread makes the synchronous call, it blocks until the work completes.

### What does FIFO mean for a concurrent queue?

Submission/dequeue ordering does not imply serial execution or completion order. Multiple tasks can overlap and finish in any order.

### How does a barrier work?

On a custom concurrent queue, a barrier waits for earlier items to finish, executes exclusively, and prevents later items from starting until it completes.

### DispatchGroup versus semaphore?

A group tracks completion of multiple operations. A semaphore is a blocking counter used to limit access or wait for signals. A group’s `notify` is asynchronous; a semaphore’s `wait` blocks a thread.

### Does `DispatchWorkItem.cancel()` stop an executing closure?

No. It sets cancellation state. The closure and any nested operation must observe that state and return or cancel cooperatively.

### What is QoS?

QoS communicates how important and latency-sensitive work is. The system uses it to make scheduling and energy decisions; it does not guarantee order or completion time.

### How can a serial queue replace a lock?

Confine mutable state to the serial queue and route every read and write through it. One task at a time means critical operations do not overlap. A lock may still be more efficient for tiny synchronous critical sections.

### Why can too much GCD concurrency hurt?

Scheduling has overhead, shared resources contend, caches suffer, and blocked tasks may lead the system to create excessive threads. Concurrency must be bounded and measured.

### GCD versus actor?

A serial queue provides runtime serialization. An actor provides compiler-aware isolation and uses task suspension rather than synchronous thread blocking. Actor methods can be reentrant across `await`, so invariants must be rechecked after suspension.

## Scenario exercises

### Scenario 1

Three independent images must be decoded, and the screen updates after all are ready.

Potential solutions:

- GCD: concurrent/global queue + group + isolated result storage + main notification
- Swift concurrency: `async let` or task group + `MainActor`

### Scenario 2

A dictionary has thousands of reads and occasional writes from many callers.

Potential solutions:

- custom concurrent queue with synchronous reads and barrier writes
- actor if application-level structured isolation is more important than parallel reads

### Scenario 3

A callback API must be exposed as an async function.

Use a checked continuation. Do not block a semaphore while waiting for the callback.

### Scenario 4

The UI freezes while code runs `globalQueue.sync { parse() }` from a button action.

Cause: the main-thread caller waits. Use asynchronous flow or an async function and update UI after completion.

## Final decision guide

```text
Need UI isolation?
  -> MainActor / main queue

Need mutable state isolation?
  -> actor; or serial queue / barrier queue for GCD design

Need several async operations to complete?
  -> async let / task group; or DispatchGroup

Need bounded resource access?
  -> async bounded design; semaphore only with care

Need delayed one-shot work?
  -> Task sleep / clock in async code; or asyncAfter

Need low-level recurring/system events?
  -> DispatchSource
```

## Back to index

[[00 - Grand Central Dispatch (GCD) Index]]
