# Protecting Shared State: Serial Queues and Barriers

## The real problem

Shared mutable state becomes unsafe when two execution contexts access it concurrently and at least one access is a write.

```swift
var count = 0

DispatchQueue.global().async { count += 1 }
DispatchQueue.global().async { count += 1 }
```

`count += 1` is a read-modify-write sequence. Both tasks may read the same value and overwrite one another. Swift’s memory model does not make ordinary variables atomic.

## Queue confinement

The strongest simple rule is:

> A piece of mutable state belongs to one isolation domain, and every access occurs through that domain.

With GCD, that domain is often a private serial queue.

```swift
final class Counter {
    private let queue = DispatchQueue(label: "com.example.counter")
    private var value = 0

    func increment() {
        queue.async {
            self.value += 1
        }
    }

    func snapshot() -> Int {
        queue.sync {
            value
        }
    }
}
```

Properties of this design:

- mutations do not overlap
- operations are ordered by submission
- a synchronous read returns a consistent snapshot
- callers cannot access `value` directly

### The queue does not protect bypassing code

```swift
func unsafeSnapshot() -> Int {
    value // Race: bypasses queue
}
```

The private access modifier helps enforce the rule but does not replace review and testing.

## Atomic operation versus atomic workflow

Protect the complete invariant, not just individual property access.

Incorrect check-then-act split:

```swift
if store.contains(id) {
    store.remove(id)
}
```

If `contains` and `remove` are separately synchronized, another operation may intervene between them.

Better:

```swift
func removeIfPresent(_ id: ID) -> Item? {
    queue.sync {
        storage.removeValue(forKey: id)
    }
}
```

The entire semantic operation is isolated.

## Concurrent readers, exclusive writer

For read-heavy state, a custom concurrent queue with barriers allows reads to overlap while writes execute exclusively.

```swift
final class Cache<Key: Hashable, Value> {
    private let queue = DispatchQueue(
        label: "com.example.cache",
        attributes: .concurrent
    )

    private var storage: [Key: Value] = [:]

    func value(for key: Key) -> Value? {
        queue.sync {
            storage[key]
        }
    }

    func insert(_ value: Value, for key: Key) {
        queue.async(flags: .barrier) {
            self.storage[key] = value
        }
    }

    func removeValue(for key: Key) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }
}
```

Barrier semantics:

```text
read A ─────┐
read B ─────┼── overlap
read C ─────┘
             [ barrier write ]  <- exclusive
read D ─────────┐
read E ─────────┘               <- may overlap after write
```

When the barrier reaches its turn:

1. the queue waits for previously submitted work to finish
2. the barrier executes alone
3. later work waits until the barrier finishes

## Barrier requirements

Use barriers on a **custom concurrent queue that you control**.

```swift
let isolationQueue = DispatchQueue(
    label: "com.example.state",
    attributes: .concurrent
)
```

A barrier on a serial queue adds no useful concurrency; the queue is already exclusive. A barrier submitted to a shared global queue does not provide the private reader/writer isolation implied by this pattern.

## Async versus sync writes

Asynchronous barrier write:

```swift
queue.async(flags: .barrier) {
    storage[key] = value
}
```

The method returns before mutation finishes. Later work submitted to the same queue observes submission order, but outside callers may incorrectly assume immediate completion.

Synchronous barrier write:

```swift
queue.sync(flags: .barrier) {
    storage[key] = value
}
```

The method returns after mutation finishes, but blocks the caller and can deadlock under reentrancy. Choose semantics based on the API contract, not speed alone.

## Returning mutable reference types

Queue isolation can be broken by returning an internal mutable object:

```swift
func object(for key: Key) -> NSMutableDictionary? {
    queue.sync { storage[key] }
}
```

The dictionary reference escapes and may be mutated outside the queue. Prefer immutable value snapshots, deep copies where necessary, or operations that keep mutation inside the isolation boundary.

Swift value types help, but a value may still contain reference-typed members. “Copied” does not always mean deeply isolated.

## Queue versus lock

| Serial queue | Lock |
|---|---|
| Can schedule async work | Usually protects synchronous critical sections |
| Naturally orders operations | Ordering is incidental to acquisition |
| Carries label and QoS context | Often lighter for tiny critical sections |
| Reentrant `sync` can deadlock | Lock behavior depends on lock type |
| Encourages ownership by an execution context | Encourages scoped mutual exclusion |

Use a lock when a tiny synchronous critical section is the clearest design. Use a serial queue when ordering, asynchronous mutation, queue context, or integration with dispatch APIs is valuable. In modern Swift, an actor is often the best application-level isolation boundary.

## Semaphore is not the default state lock

A binary semaphore can technically exclude access, but it has weaker ownership semantics and makes accidental blocking easy:

```swift
semaphore.wait()
defer { semaphore.signal() }
// critical section
```

Prefer a purpose-built lock, serial queue, or actor. Semaphores are better suited to resource counting and carefully bounded bridging.

## Performance considerations

A reader/writer barrier design is not automatically faster than a serial queue. It helps only when:

- reads are sufficiently expensive
- reads greatly outnumber writes
- there is meaningful concurrent demand
- returned data does not escape unsafely
- queue overhead does not dominate

Start with the simplest correct isolation model; measure before increasing complexity.

## Related

- [[06 - DispatchGroup, DispatchWorkItem, and DispatchSemaphore]]
- [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]
- [[11 - GCD and Modern Swift Concurrency]]

## Official reference

- [Dispatch barriers](https://developer.apple.com/documentation/dispatch/dispatch-barrier)

