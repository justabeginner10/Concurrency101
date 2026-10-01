# GCD and Modern Swift Concurrency

GCD and Swift concurrency coexist, but they operate at different abstraction levels.

GCD centers on queues, closures, blocking primitives, and system scheduling. Swift concurrency centers on tasks, suspension, structured lifetimes, actors, `Sendable`, and compiler-checked isolation.

## Concept mapping

| GCD concept | Modern Swift counterpart | Important difference |
|---|---|---|
| `DispatchQueue.main.async` | `@MainActor`, `MainActor.run`, `Task { @MainActor in ... }` | Main actor expresses isolation in the type system |
| Serial isolation queue | `actor` | Actor isolation is compiler-aware and supports suspension |
| Nested callbacks | `async`/`await` | Linear control flow and native errors |
| `DispatchGroup` | `async let`, task group | Child-task lifetime is structured |
| `DispatchWorkItem.cancel()` | `Task.cancel()` | Both are cooperative; Swift cancellation propagates through task structure |
| Semaphore wait | `await`, async semaphore/channel design | `await` suspends a task rather than blocking a thread |
| Queue QoS | Task priority | Both express scheduling intent, not correctness or deadlines |

## Main queue to MainActor

GCD:

```swift
DispatchQueue.main.async {
    self.titleLabel.text = title
}
```

Swift concurrency:

```swift
@MainActor
func display(title: String) {
    titleLabel.text = title
}
```

Or:

```swift
await MainActor.run {
    titleLabel.text = title
}
```

`@MainActor` documents and enforces the isolation requirement across calls. It is stronger than remembering to dispatch at every mutation site.

## Serial queue to actor

GCD:

```swift
final class Counter {
    private let queue = DispatchQueue(label: "counter")
    private var value = 0

    func increment() {
        queue.async { self.value += 1 }
    }

    func snapshot() -> Int {
        queue.sync { value }
    }
}
```

Actor:

```swift
actor Counter {
    private var value = 0

    func increment() {
        value += 1
    }

    func snapshot() -> Int {
        value
    }
}
```

Callers cross isolation with `await`:

```swift
await counter.increment()
let value = await counter.snapshot()
```

The caller’s task suspends rather than blocking a thread.

### Actor reentrancy differs from a serial queue

An actor-isolated function can suspend at `await`, allowing another task to enter the actor before the first resumes:

```swift
actor Account {
    private var balance = 100

    func purchase() async throws {
        guard balance >= 50 else { return }
        let approval = try await requestApproval()
        // State may have changed while suspended.
        guard approval, balance >= 50 else { return }
        balance -= 50
    }
}
```

Actor isolation prevents data races, but invariants spanning an `await` must be revalidated. A GCD serial block that never dispatches away runs to completion without another block on that queue interleaving.

## DispatchGroup to `async let`

GCD:

```swift
// Requires callback coordination, group membership, result isolation,
// and manual error aggregation.
```

Swift:

```swift
func loadDashboard() async throws -> DashboardData {
    async let profile = loadProfile()
    async let messages = loadMessages()

    return try await DashboardData(
        profile: profile,
        messages: messages
    )
}
```

The child tasks belong to the surrounding scope and are awaited before it exits.

## Dynamic fan-out with a task group

```swift
func loadImages(_ urls: [URL]) async throws -> [UIImage] {
    try await withThrowingTaskGroup(of: UIImage.self) { group in
        for url in urls {
            group.addTask {
                try await loadImage(url)
            }
        }

        var images: [UIImage] = []
        for try await image in group {
            images.append(image)
        }
        return images
    }
}
```

Task groups provide structured cancellation and error propagation. For very large collections, still bound concurrency rather than adding unlimited child tasks.

## Bridging a callback API

Use a checked continuation rather than a semaphore:

```swift
func fetchData() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetch { result in
            continuation.resume(with: result)
        }
    }
}
```

Rules:

- resume exactly once
- resume on every completion path
- continuation resumption does not require a particular queue unless the legacy API does
- separately bridge cancellation if the underlying operation supports it

## `Task.detached` is not a generic replacement for global queues

Detached tasks do not inherit actor context or ordinary task-local structure in the same way as child/unstructured tasks. Use them only when work is intentionally independent. Most application code should prefer a normal `Task`, `async let`, or task group.

Similarly, do not wrap every synchronous function in `Task.detached` to make it “background.” Decide whether the work is CPU-bound, blocking, actor-isolated, cancellable, and safe to send.

## Mixing queues and actors

Legacy services may call back on private queues. Cross into actor isolation explicitly:

```swift
legacyService.start { [weak self] value in
    Task { @MainActor [weak self] in
        self?.display(value)
    }
}
```

Avoid relying on whichever thread happened to invoke the callback.

Be cautious when blocking GCD code waits for async Swift tasks. There is no safe general-purpose “sync wait for async” adapter. It can exhaust cooperative executor threads or deadlock an isolation dependency. Keep the boundary asynchronous.

## `Sendable`

Swift concurrency uses `Sendable` to model values that can safely cross isolation boundaries. Queue-based GCD code historically relied more on convention and runtime tooling. Under strict concurrency checking, dispatch closures and captured values can reveal unsafe transfers.

Prefer:

- immutable value types
- explicitly synchronized reference types
- actors for mutable shared state
- avoiding `@unchecked Sendable` unless the synchronization proof is real and documented

## When GCD remains appropriate

- maintaining queue-based APIs and existing codebases
- dispatch sources and low-level event integration
- custom concurrent queue barriers
- system APIs that expose dispatch queues
- narrow low-level scheduling and synchronization needs
- interoperability with C/Objective-C dispatch code

## When Swift concurrency is usually clearer

- application workflow composed from asynchronous operations
- UI isolation
- request/response APIs with values and errors
- tree-shaped child work
- cancellation propagation
- mutable subsystem isolation

The goal is not to replace every queue mechanically. Migrate at semantic boundaries: turn callback services into async functions, queue-isolated state into an actor where appropriate, and UI entry points into `@MainActor` APIs.

## Related

- [[01 - GCD Mental Model and Architecture]]
- [[05 - Protecting Shared State - Serial Queues and Barriers]]
- [[10 - Practical iOS Patterns and Worked Examples]]

## Official references

- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [MainActor](https://developer.apple.com/documentation/swift/mainactor)

