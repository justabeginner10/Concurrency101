# Memory Management, Closure Capture, and Autorelease Pools

## Dispatch closures retain captures

An asynchronously submitted closure must survive after the submitting function returns, so the queue retains it until execution and release. The closure strongly captures referenced objects by default.

```swift
queue.async {
    self.performImport()
}
```

Here, `self` remains alive while the closure is pending and executing.

This is not automatically a memory leak. For finite work it often expresses correct ownership: the operation keeps its required object alive.

## Temporary retention cycle

```text
self -> queue -> pending closure -> self
```

If `self` owns the queue and a pending closure captures `self`, a cycle exists temporarily. Once a normal finite closure runs and the queue releases it, the cycle breaks.

It becomes effectively permanent when work never completes or is indefinitely retained, for example:

- a repeating dispatch source handler
- an indefinitely suspended queue
- a work item stored forever by its owner
- a closure blocked forever in a deadlock

## Weak capture

```swift
queue.async { [weak self] in
    guard let self else { return }
    self.performOptionalWork()
}
```

Use weak capture when the operation should become irrelevant if the owner disappears.

Do not apply `[weak self]` mechanically. Ask what lifecycle is correct:

| Intent | Capture choice |
|---|---|
| Operation must finish and legitimately owns the worker | Strong capture may be correct |
| Delayed UI action should disappear with the screen | Weak capture often fits |
| Long-lived callback should not own its controller | Weak capture or explicit cancellation |
| Value needed independently of owner | Capture the value directly |

### Capture only what is needed

```swift
let request = self.request
let service = self.service

queue.async {
    service.send(request)
}
```

This makes dependencies and lifetime clearer than capturing an entire controller.

## Weak–strong timing

```swift
queue.async { [weak self] in
    guard let self else { return }
    performSeveralSteps(using: self)
}
```

After the `guard`, the local strong reference keeps `self` alive for the rest of the closure. That is usually desirable: the operation does not lose its owner halfway through.

If each step should independently tolerate disappearance, copy immutable dependencies or design an explicitly cancellable operation.

## Capturing mutable variables

```swift
var result = 0

queue.async {
    result = calculate()
}

print(result) // Race and likely stale value
```

Closure capture does not synchronize access. The outer scope and closure can race. Communicate results through a completion closure, an isolated state container, or `async`/`await`.

Under strict Swift concurrency checking, sending non-`Sendable` captured state across concurrency boundaries may produce diagnostics. Treat these diagnostics as design feedback, not obstacles to silence blindly.

## UI object lifetimes

```swift
workerQueue.async { [weak self] in
    guard let self else { return }
    let output = self.makeOutput()

    DispatchQueue.main.async { [weak self] in
        self?.render(output)
    }
}
```

The view controller might disappear during either phase. Whether processing should continue is a product decision:

- if output is cacheable or globally useful, separate processing from the view controller
- if work exists solely for that screen, weak ownership and explicit cancellation fit
- if a service owns the operation, let the service retain it and deliver results conditionally

## Autorelease pools

Swift uses ARC, but many Foundation and Objective-C APIs create autoreleased temporary objects. A long-running block can accumulate these objects before the surrounding pool drains.

```swift
queue.async {
    for url in urls {
        autoreleasepool {
            let data = try? Data(contentsOf: url)
            inspect(data)
        }
    }
}
```

An inner `autoreleasepool` can reduce peak memory during large loops involving Foundation or Objective-C objects.

## Queue autorelease frequency

```swift
let queue = DispatchQueue(
    label: "com.example.foundation-heavy",
    qos: .utility,
    autoreleaseFrequency: .workItem
)
```

Behaviors:

- `.inherit`: inherit from the target queue
- `.workItem`: create and drain a pool around each work item
- `.never`: the queue does not create a per-item pool

Do not reach for this as a first-line performance setting. Use Instruments to verify memory behavior. An explicit `autoreleasepool` inside a large loop gives more precise lifetime control.

## Dispatch source lifecycle

A source retains its event handler, and the handler may retain the owner:

```swift
timer.setEventHandler { [weak self] in
    self?.tick()
}
```

Also cancel sources when their work is no longer needed. Weak capture prevents one ownership cycle, but it does not itself release external resources managed by the source.

## Work item cancellation and lifetime

Cancelling a `DispatchWorkItem` does not necessarily release its captured values immediately. The item may still be retained by a queue, an owner property, or notification relationships. Clear stored work items when finished and make cancellation part of an explicit lifecycle.

## Practical checklist

- Does this closure need to keep its owner alive?
- Is the operation finite, repeating, suspended, or potentially blocked?
- Can immutable values be captured instead of an entire object?
- Is mutable captured state synchronized?
- Are Foundation temporaries causing a memory spike?
- Who cancels timers, sources, network work, and stored work items?
- Does cancellation actually propagate to nested operations?

## Related

- [[06 - DispatchGroup, DispatchWorkItem, and DispatchSemaphore]]
- [[07 - Scheduling, Time, Queue Configuration, and Advanced APIs]]
- [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]

## Official reference

- [DispatchQueue.AutoreleaseFrequency](https://developer.apple.com/documentation/dispatch/dispatchqueue/autoreleasefrequency)

