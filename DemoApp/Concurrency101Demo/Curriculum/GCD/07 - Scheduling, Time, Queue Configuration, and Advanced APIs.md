# Scheduling, Time, Queue Configuration, and Advanced APIs

## `asyncAfter`: delayed eligibility

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    showTooltip()
}
```

The deadline is the earliest time at which the work becomes eligible. Execution may happen later because the queue is busy or the system is under load.

This API does not reserve a sleeping thread.

### `DispatchTime`

`DispatchTime` is based on a monotonic clock and is appropriate for elapsed-time scheduling:

```swift
let deadline = DispatchTime.now() + .milliseconds(250)
```

A monotonic clock does not jump when the user changes wall-clock time.

### `DispatchWallTime`

Wall time relates to the real-world clock. Use it only when behavior should correspond to wall-clock changes. Calendar-style requirements are often better modeled with higher-level date and notification APIs.

## Repeating work: DispatchSourceTimer

Repeatedly chaining `asyncAfter` can drift because the next delay may be scheduled only after prior work completes. A dispatch timer source is designed for timer events:

```swift
final class Poller {
    private let queue = DispatchQueue(label: "com.example.poller")
    private var timer: DispatchSourceTimer?

    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now(),
            repeating: .seconds(30),
            leeway: .seconds(2)
        )
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.setCancelHandler {
            // Release timer-associated resources if needed.
        }

        self.timer = timer
        timer.activate()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {}
}
```

`leeway` gives the system flexibility to coalesce wakeups and save energy. Request only the precision the feature actually needs.

Keep lifecycle rules explicit:

- activate a newly created inactive source exactly once
- cancellation is not activation reversal
- event handlers must obey the same thread-safety rules as any queued closure
- avoid retaining the owner forever through a repeating handler

## Dispatch sources

Dispatch sources translate low-level events into coalesced event-handler invocations on a chosen queue. Source categories include:

- timers
- process events
- file-system objects
- signals
- user-data add/or/replace sources
- read/write readiness for file descriptors

Conceptual flow:

```text
kernel/system event -> DispatchSource -> selected queue -> event handler
```

Events may be coalesced. A source handler should inspect source data and relevant state rather than assuming one callback per original event.

For ordinary URL loading, file observation, or app lifecycle work, prefer the appropriate high-level Foundation or platform API. Dispatch sources are valuable when low-level event integration is truly required.

## `concurrentPerform`

```swift
DispatchQueue.concurrentPerform(iterations: inputs.count) { index in
    outputs[index] = transform(inputs[index])
}
```

`concurrentPerform` applies a closure across an integer range and does not return until all iterations finish. It is best suited to substantial, independent CPU work.

Important constraints:

- the calling thread participates or waits; never use it carelessly on the main thread
- each iteration must access independent storage or synchronize shared state
- append to a common array is unsafe
- small iterations can lose to scheduling overhead
- blocking each iteration can create thread pressure

Pre-sized independent output slots can be appropriate only when the data structure and memory access are safe for disjoint concurrent mutation. When uncertain, return values through safer aggregation or use structured concurrency.

## DispatchIO

`DispatchIO` provides channel-based asynchronous file-descriptor I/O with integration into dispatch queues. It supports stream and random-access modes, cleanup handlers, high/low water marks, and chunked delivery.

It is a specialized low-level tool. Most iOS application code should begin with Foundation APIs such as `Data`, `FileHandle`, URL loading, or modern async sequences. Use `DispatchIO` when precise nonblocking descriptor I/O and chunk management are requirements.

## DispatchData

`DispatchData` represents potentially noncontiguous byte regions and can reduce copying in low-level I/O pipelines. It is useful with `DispatchIO` and dispatch sources. For ordinary model and networking code, Swift `Data` is usually simpler.

## Initially inactive queues and activation

```swift
let queue = DispatchQueue(
    label: "com.example.prepared",
    attributes: .initiallyInactive
)

queue.async { firstPreparedOperation() }
queue.async { secondPreparedOperation() }
queue.activate()
```

This supports configuring and preloading work before atomic activation. Activation is permanent; an activated object cannot become initially inactive again.

## Suspend and resume

```swift
queue.suspend()
queue.resume()
```

Suspension prevents new blocks from beginning but does not stop one already executing. Suspend/resume calls must be balanced. Prefer explicit workflow state because:

- imbalance is easy
- suspended work retains its captures
- dependencies may wait indefinitely
- cancellation and pause semantics become unclear

## Autorelease frequency

Custom queues can specify how autoreleased Objective-C objects are managed:

```swift
let queue = DispatchQueue(
    label: "com.example.import",
    qos: .utility,
    autoreleaseFrequency: .workItem
)
```

Options:

- `.inherit`: inherit behavior from the target queue
- `.workItem`: create and drain an autorelease pool around each work item
- `.never`: do not establish a pool for each item

This is primarily relevant when Swift code interacts with Objective-C/Foundation objects and creates many autoreleased temporaries. See [[08 - Memory Management, Closure Capture, and Autorelease Pools]].

## Dispatch preconditions

Assert execution-context invariants:

```swift
func updateViewHierarchy() {
    dispatchPrecondition(condition: .onQueue(.main))
    // UI work
}
```

Predicates include:

- `.onQueue(queue)`
- `.notOnQueue(queue)`
- `.onQueueAsBarrier(queue)`

These are useful diagnostics but not synchronization. A precondition can detect a violated assumption; it cannot make access safe.

## One-time initialization

Old Objective-C GCD code often used `dispatch_once`. In Swift, type and global stored properties provide thread-safe lazy initialization:

```swift
final class SharedConfiguration {
    static let instance = SharedConfiguration()
    private init() {}
}
```

Prefer Swift language initialization semantics instead of recreating a once token.

## Official references

- [Dispatch framework](https://developer.apple.com/documentation/dispatch)
- [DispatchSource](https://developer.apple.com/documentation/dispatch/dispatchsource)
- [DispatchSourceTimer](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer)
- [DispatchIO](https://developer.apple.com/documentation/dispatch/dispatchio)
- [DispatchQueue.AutoreleaseFrequency](https://developer.apple.com/documentation/dispatch/dispatchqueue/autoreleasefrequency)
- [dispatchPrecondition](https://developer.apple.com/documentation/dispatch/dispatchprecondition(condition:))
