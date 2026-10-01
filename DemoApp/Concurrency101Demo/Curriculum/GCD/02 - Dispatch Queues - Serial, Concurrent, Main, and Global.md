# Dispatch Queues: Serial, Concurrent, Main, and Global

## Queue categories

GCD applications use four practical queue categories:

| Queue | Serial/concurrent | Provided by | Primary use |
|---|---|---|---|
| Main | Serial | System | UI and main-run-loop work |
| Global | Concurrent | System | Independent work classified by QoS |
| Custom serial | Serial | App/framework | Ordering and state isolation |
| Custom concurrent | Concurrent | App/framework | Controlled parallel work and barrier-based synchronization |

## Serial queues

Create a serial queue by omitting `.concurrent`:

```swift
let queue = DispatchQueue(label: "com.example.serial")
```

A serial queue has a **width of one**: at most one of its work items executes at a time.

```swift
queue.async { print("A") }
queue.async { print("B") }
queue.async { print("C") }
```

The prints occur in A–B–C order, although the caller does not wait.

### Typical uses

- isolate mutable state
- preserve transaction or event ordering
- serialize access to a non-thread-safe dependency
- coordinate a state machine
- avoid a lock around a set of related operations

### Independent serial queues may overlap

Serial applies only within a queue:

```swift
let queueA = DispatchQueue(label: "com.example.a")
let queueB = DispatchQueue(label: "com.example.b")

queueA.async { taskA() }
queueB.async { taskB() }
```

`taskA()` and `taskB()` may execute concurrently because they belong to different queues.

## Concurrent queues

```swift
let queue = DispatchQueue(
    label: "com.example.concurrent",
    attributes: .concurrent
)
```

A concurrent queue permits several submitted items to overlap. It is appropriate only when the tasks are independent or their shared data is synchronized.

```swift
queue.async { decodeImage(firstData) }
queue.async { decodeImage(secondData) }
queue.async { decodeImage(thirdData) }
```

The order in which decoding finishes is unspecified.

### Private concurrent queue or global queue?

Use a global queue for ordinary independent work. Create a custom concurrent queue when the queue itself provides important semantics, especially:

- barrier-based reader/writer isolation
- a meaningful subsystem label
- queue-specific context
- target-queue hierarchy
- deliberate configuration such as initially inactive behavior

Avoid creating many private concurrent queues. Concurrent blocking work can pressure GCD into creating more threads, and many unrelated queues obscure resource limits.

## The main queue

```swift
DispatchQueue.main
```

Properties:

- serial
- bound to the process’s main thread
- integrated with the app’s event loop
- used for UIKit and other main-thread-bound APIs

```swift
workerQueue.async {
    let model = parseLargeDocument()

    DispatchQueue.main.async {
        self.apply(model)
    }
}
```

### Main thread versus main queue

The main queue runs on the main thread, but “currently on the main thread” and “executing as a main-queue work item” are not always identical concepts in low-level integrations. Application code should normally express UI isolation with `@MainActor` in modern Swift or main-queue dispatch in GCD-based code.

### Why main-queue work must be short

While one main-queue task runs, subsequent UI events cannot be serviced. Never put the following on the main queue unless known to be trivial:

- synchronous network or disk waits
- large JSON decoding
- expensive image transformations
- semaphore/group waits
- long database operations
- arbitrary sleeps

## Global concurrent queues

```swift
DispatchQueue.global(qos: .userInitiated)
DispatchQueue.global(qos: .utility)
DispatchQueue.global(qos: .background)
```

Global queues are shared system resources. Select them by the work’s QoS rather than by an imagined fixed number of threads.

Good use:

```swift
DispatchQueue.global(qos: .utility).async {
    generateExportArchive()
}
```

Risky use:

```swift
for request in requests {
    DispatchQueue.global().async {
        blockingCallThatMayTakeMinutes(request)
    }
}
```

Submitting unbounded blocking work can produce thread explosion or starvation. Prefer truly asynchronous APIs and explicit concurrency limits.

## Queue labels

Labels make crash reports, Instruments traces, and debugger output understandable:

```swift
let queue = DispatchQueue(
    label: "com.mycompany.myapp.thumbnail-cache"
)
```

Use stable reverse-DNS names. The label does not impose uniqueness; two queues may have the same label, but doing so makes diagnosis harder.

## Queue attributes

### `.concurrent`

```swift
attributes: .concurrent
```

Allows overlapping work.

### `.initiallyInactive`

```swift
let queue = DispatchQueue(
    label: "com.example.deferred",
    attributes: .initiallyInactive
)

queue.async { startPreparedWork() }
queue.activate()
```

An initially inactive queue accepts work but does not execute it until activated. Activation is one-way. This is specialized; ordinary code should usually submit work only when it is ready.

Attributes can be combined:

```swift
attributes: [.concurrent, .initiallyInactive]
```

## Target queues

A custom queue can target another queue:

```swift
let root = DispatchQueue(
    label: "com.example.root",
    qos: .utility,
    attributes: .concurrent
)

let cacheQueue = DispatchQueue(
    label: "com.example.cache",
    target: root
)

let fileQueue = DispatchQueue(
    label: "com.example.files",
    target: root
)
```

Each child serial queue preserves its own ordering, while the target establishes a shared execution hierarchy and inherited scheduling context. Target queues are useful in frameworks and advanced resource coordination, but unnecessary hierarchy can make execution behavior harder to understand.

Set target relationships during setup, before queues are actively used. Mutating queue configuration while work is in flight is easy to misuse.

## Suspending and resuming

Dispatch objects expose `suspend()` and `resume()`, but these are low-level controls:

```swift
queue.suspend()
queue.resume()
```

Suspension stops new work from beginning; it does not interrupt work already running. Calls must be balanced. Releasing or abandoning an indefinitely suspended queue with captured resources can cause serious lifetime problems.

For most application workflows, model “paused” state explicitly instead of suspending a queue.

## Queue-specific data

`DispatchSpecificKey` associates contextual information with a queue:

```swift
private let key = DispatchSpecificKey<String>()
private let queue = DispatchQueue(label: "com.example.store")

queue.setSpecific(key: key, value: "store")

queue.async {
    precondition(DispatchQueue.getSpecific(key: key) == "store")
}
```

Uses include diagnosing queue context or implementing carefully designed reentrancy checks. Do not use it as a general replacement for explicit isolation.

## Choosing a queue

```text
UI mutation?
  yes -> MainActor / main queue
  no
   |
Shared mutable state that requires ordering?
  yes -> actor or custom serial queue
  no
   |
Independent meaningful CPU work?
  yes -> global queue with appropriate QoS
  no  -> execute directly; dispatching may add needless overhead
```

## Related

- [[03 - async, sync, Ordering, and Execution Semantics]]
- [[04 - Quality of Service (QoS) and Priority]]
- [[05 - Protecting Shared State - Serial Queues and Barriers]]

## Official references

- [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
- [Creating a queue with attributes and a target](https://developer.apple.com/documentation/dispatch/dispatchqueue/init(label:qos:attributes:autoreleasefrequency:target:))
- [DispatchSpecificKey](https://developer.apple.com/documentation/dispatch/dispatchspecifickey)
