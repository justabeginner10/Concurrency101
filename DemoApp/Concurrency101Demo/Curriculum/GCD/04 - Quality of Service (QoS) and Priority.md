# Quality of Service (QoS) and Priority

Quality of Service communicates the **intent and importance** of work. The system uses it to balance responsiveness, energy consumption, CPU scheduling, I/O behavior, and available resources.

QoS is not:

- a deadline
- a guaranteed start time
- permission to monopolize the CPU
- a fixed mapping to one thread or core

## QoS classes

| QoS | Meaning | Examples |
|---|---|---|
| `.userInteractive` | Needed immediately to maintain an interactive experience | animation preparation, event handling, tiny UI-critical calculations |
| `.userInitiated` | User requested the result and is actively waiting | open document, load selected conversation, apply chosen filter |
| `.default` | Active work without more specific classification | general application work |
| `.utility` | Longer-running work; progress may be visible, but immediate completion is not essential | export, download processing, bulk import |
| `.background` | Maintenance the user is not waiting for | cleanup, prefetch, indexing, cache pruning |
| `.unspecified` | No explicit classification | mainly for inherited or legacy contexts |

## Creating queues with QoS

```swift
let thumbnailQueue = DispatchQueue(
    label: "com.example.thumbnails",
    qos: .userInitiated,
    attributes: .concurrent
)
```

Using a global queue:

```swift
DispatchQueue.global(qos: .utility).async {
    createArchive()
}
```

## Choosing based on user intent

Ask: **What is the user doing while this work happens?**

```text
Must happen for the next frame or direct interaction?
    -> userInteractive

User explicitly requested it and cannot proceed without the result?
    -> userInitiated

User knows it is happening but can continue doing other things?
    -> utility

Invisible maintenance or speculative work?
    -> background
```

Do not classify by implementation alone. The same image decoding function may deserve different QoS depending on whether it renders the visible screen or prewarms an offscreen cache.

## QoS and energy

Higher QoS asks the system to spend resources to reduce latency. Using a higher class than necessary can:

- consume more battery
- increase thermal pressure
- compete with UI-critical work
- reduce overall application and system responsiveness

Using a lower class than necessary can make user-visible operations feel stalled.

## Priority inversion

Priority inversion occurs when high-priority work depends on lower-priority work:

```text
High-QoS task waits for lock/resource
                 |
                 v
Low-QoS task owns resource but receives little CPU time
```

The system can apply priority donation or escalation in some situations, but the design should minimize long cross-QoS dependencies.

Example risk:

```swift
let backgroundQueue = DispatchQueue(
    label: "com.example.cache-maintenance",
    qos: .background
)

// Later, user-initiated work synchronously needs state owned by that queue.
let value = backgroundQueue.sync {
    expensiveCacheLookup()
}
```

If interactive work frequently waits on the background queue, the queue’s role or API is probably misclassified.

## Per-work-item QoS

An asynchronous submission can provide QoS and flags:

```swift
queue.async(qos: .userInitiated) {
    calculateVisibleResult()
}
```

Prefer a coherent QoS for a subsystem. Per-item overrides are useful when one queue handles work with genuinely different urgency, but too many overrides make scheduling intent hard to audit.

## Relative priority

`DispatchQoS` supports a relative priority within the same class:

```swift
let qos = DispatchQoS(qosClass: .utility, relativePriority: -5)
```

This is an advanced tuning mechanism. QoS class carries the important semantic meaning; do not build correctness around relative priority or assume it creates deterministic ordering.

## QoS propagation

QoS can be inherited or inferred through queue and work relationships. GCD may temporarily adjust priority when higher-priority work synchronously depends on lower-priority work. Exact propagation rules are nuanced and should be treated as scheduling assistance, not a correctness mechanism.

Design principles:

- classify work at the point where user intent is known
- avoid blocking high-QoS work on long low-QoS work
- do not use priority to enforce task order
- verify behavior with Instruments instead of guessing

## Common mistakes

### Making everything user-interactive

This destroys the meaning of prioritization and increases energy cost.

### Using background for all non-UI code

User-requested parsing that drives the visible screen is normally user-initiated, not background.

### Assuming QoS creates serial order

Priority affects scheduling preference; it is not a dependency graph.

### Using priority to fix a race

Changing which task is likely to run first does not synchronize memory and cannot correct a data race.

## Related

- [[02 - Dispatch Queues - Serial, Concurrent, Main, and Global]]
- [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]

## Official references

- [DispatchQoS](https://developer.apple.com/documentation/dispatch/dispatchqos)
- [QoS classes](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass-swift.enum)

