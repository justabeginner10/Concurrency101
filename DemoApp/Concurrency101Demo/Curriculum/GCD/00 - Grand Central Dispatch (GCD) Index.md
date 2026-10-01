# Grand Central Dispatch (GCD) in Swift and iOS

> [!summary]
> Grand Central Dispatch is Apple’s work-scheduling system. You submit closures to queues; the system decides when and on which threads to execute them. A queue is an ordering and isolation mechanism—not a thread.

## Learning path

1. [[01 - GCD Mental Model and Architecture]]
2. [[02 - Dispatch Queues - Serial, Concurrent, Main, and Global]]
3. [[03 - async, sync, Ordering, and Execution Semantics]]
4. [[04 - Quality of Service (QoS) and Priority]]
5. [[05 - Protecting Shared State - Serial Queues and Barriers]]
6. [[06 - DispatchGroup, DispatchWorkItem, and DispatchSemaphore]]
7. [[07 - Scheduling, Time, Queue Configuration, and Advanced APIs]]
8. [[08 - Memory Management, Closure Capture, and Autorelease Pools]]
9. [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]
10. [[10 - Practical iOS Patterns and Worked Examples]]
11. [[11 - GCD and Modern Swift Concurrency]]
12. [[12 - GCD Quick Reference and Interview Questions]]

## The four questions to ask before dispatching work

1. **Does this work touch the UI?** Use `MainActor` in modern Swift, or the main dispatch queue in GCD code.
2. **Must it be ordered or mutually exclusive?** Use an isolation mechanism such as a serial queue or an actor.
3. **Can independent units safely overlap?** Use concurrency only when the work and data model allow it.
4. **Should the caller wait?** Prefer asynchronous composition. Blocking with `sync`, `wait`, or a semaphore should be deliberate.

## Core vocabulary

| Term | Meaning |
|---|---|
| Work item | A closure or function submitted for execution |
| Dispatch queue | A FIFO submission context that executes work serially or concurrently |
| Serial queue | Allows only one of its work items to execute at a time |
| Concurrent queue | May execute multiple submitted work items at the same time |
| Main queue | A serial queue bound to the app’s main thread |
| Global queue | A system-provided shared concurrent queue selected by QoS |
| `async` | Submit work and return without waiting for it to finish |
| `sync` | Submit work and block the caller until it finishes |
| QoS | A statement of the work’s importance, latency sensitivity, and energy intent |
| Barrier | Exclusive work placed among ordinary work on a custom concurrent queue |
| Group | Tracks completion of several asynchronous operations |
| Semaphore | A blocking counter that limits access or bridges synchronization boundaries |
| Dispatch source | Converts low-level system events into queue-delivered handlers |

## One-sentence mental model

> Queue type controls whether submitted work may overlap; submission type controls whether the caller waits.

## Official references

- [Dispatch framework](https://developer.apple.com/documentation/dispatch)
- [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
- [Concurrency Programming Guide: Dispatch Queues](https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationQueues/OperationQueues.html)

---

Tags: #swift #ios #gcd #concurrency #dispatch
