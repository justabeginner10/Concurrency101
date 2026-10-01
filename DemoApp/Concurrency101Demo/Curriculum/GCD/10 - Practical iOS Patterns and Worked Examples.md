# Practical iOS Patterns and Worked Examples

## Pattern 1: expensive transformation, then UI update

```swift
final class PhotoViewController: UIViewController {
    @IBOutlet private weak var imageView: UIImageView!

    private let processingQueue = DispatchQueue(
        label: "com.example.photo-processing",
        qos: .userInitiated
    )

    func display(data: Data) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let output = self.decodeAndTransform(data)

            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = output
            }
        }
    }

    private func decodeAndTransform(_ data: Data) -> UIImage? {
        // Expensive work; no UIKit hierarchy mutation here.
        UIImage(data: data)
    }
}
```

Design notes:

- serial processing prevents an unbounded number of expensive transforms
- `.userInitiated` reflects a visible user request
- only the final UI mutation runs on main
- weak capture allows work to become irrelevant when the screen disappears

If decoded results should outlive the screen, move processing into a service/cache rather than tying ownership to the controller.

## Pattern 2: serial state store

```swift
final class TokenStore {
    private let queue = DispatchQueue(
        label: "com.example.token-store"
    )

    private var token: String?

    func set(_ newValue: String?) {
        queue.async {
            self.token = newValue
        }
    }

    func snapshot() -> String? {
        queue.sync {
            token
        }
    }
}
```

The API has “eventually complete” writes and immediate snapshot reads. Because both are submitted to the same serial queue, a `snapshot()` submitted after `set()` from the same caller sees that earlier mutation once its synchronous block runs.

If callers require `set()` itself to complete before returning, use a synchronous mutation carefully or redesign around completion/async APIs.

## Pattern 3: read-heavy cache with barriers

```swift
final class ImageCache {
    private let queue = DispatchQueue(
        label: "com.example.image-cache",
        attributes: .concurrent
    )

    private var images: [URL: UIImage] = [:]

    func image(for url: URL) -> UIImage? {
        queue.sync {
            images[url]
        }
    }

    func insert(_ image: UIImage, for url: URL) {
        queue.async(flags: .barrier) {
            self.images[url] = image
        }
    }

    func removeAll(completion: (() -> Void)? = nil) {
        queue.async(flags: .barrier) {
            self.images.removeAll()
            completion?()
        }
    }
}
```

The completion executes on the cache queue. Document that fact or explicitly deliver completion on a caller-selected/main queue.

## Pattern 4: fan-out/fan-in using a group

```swift
struct DashboardData {
    let profile: Profile
    let messages: [Message]
}

final class DashboardLoader {
    private let stateQueue = DispatchQueue(
        label: "com.example.dashboard-results"
    )

    func load(completion: @escaping (Result<DashboardData, Error>) -> Void) {
        let group = DispatchGroup()
        var profileResult: Result<Profile, Error>?
        var messagesResult: Result<[Message], Error>?

        group.enter()
        loadProfile { [stateQueue] result in
            stateQueue.sync { profileResult = result }
            group.leave()
        }

        group.enter()
        loadMessages { [stateQueue] result in
            stateQueue.sync { messagesResult = result }
            group.leave()
        }

        group.notify(queue: stateQueue) {
            let combined: Result<DashboardData, Error>

            switch (profileResult, messagesResult) {
            case let (.success(profile)?, .success(messages)?):
                combined = .success(
                    DashboardData(profile: profile, messages: messages)
                )
            case let (.failure(error)?, _):
                combined = .failure(error)
            case let (_, .failure(error)?):
                combined = .failure(error)
            default:
                preconditionFailure("Group completed without both results")
            }

            DispatchQueue.main.async {
                completion(combined)
            }
        }
    }

    private func loadProfile(completion: @escaping (Result<Profile, Error>) -> Void) {}
    private func loadMessages(completion: @escaping (Result<[Message], Error>) -> Void) {}
}
```

The result variables are isolated because callbacks may arrive on different queues. Modern Swift would express this more safely with `async let` or a task group.

## Pattern 5: debounced search

```swift
final class SearchDebouncer {
    private var pending: DispatchWorkItem?
    private let delay: DispatchTimeInterval = .milliseconds(300)

    func schedule(_ action: @escaping () -> Void) {
        pending?.cancel()

        let item = DispatchWorkItem(block: action)
        pending = item

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: item
        )
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}
```

This prevents a pending closure from doing useful work after a newer one replaces it. Cancellation of already-started downstream work must be separately designed.

## Pattern 6: bounded file processing

A simple semaphore limit:

```swift
let limit = DispatchSemaphore(value: 2)
let completionGroup = DispatchGroup()
let queue = DispatchQueue.global(qos: .utility)

for url in urls {
    completionGroup.enter()
    queue.async {
        limit.wait()
        defer {
            limit.signal()
            completionGroup.leave()
        }

        autoreleasepool {
            processFile(at: url)
        }
    }
}

completionGroup.notify(queue: .main) {
    showImportComplete()
}
```

This is acceptable for modest, known input sizes. For thousands of operations, avoid submitting thousands of blocks that wait. Use a bounded producer, `OperationQueue`, or structured concurrency design.

## Pattern 7: callback queue as an API parameter

Library APIs should make callback context explicit:

```swift
func loadReport(
    callbackQueue: DispatchQueue = .main,
    completion: @escaping (Result<Report, Error>) -> Void
) {
    workerQueue.async {
        let result = Result { try self.buildReport() }
        callbackQueue.async {
            completion(result)
        }
    }
}
```

Benefits:

- callers know where completion runs
- UI clients can use main
- tests can use a controlled serial queue
- the API avoids surprising synchronous callbacks

In modern Swift, prefer an `async throws -> Report` function and let the caller choose actor isolation.

## Pattern 8: avoid nested queue ping-pong

Hard-to-reason code:

```swift
queueA.async {
    queueB.async {
        DispatchQueue.main.async {
            queueA.async {
                // Why are we here?
            }
        }
    }
}
```

Improve it by:

- assigning each state to one clear isolation owner
- separating pure computation from isolated mutation
- returning explicit results
- using structured concurrency for sequential async flow

## Pattern 9: queue-confined state machine

```swift
final class ConnectionStateMachine {
    enum State {
        case idle
        case connecting
        case connected
        case failed(Error)
    }

    private let queue = DispatchQueue(
        label: "com.example.connection-state"
    )
    private var state: State = .idle

    func connect() {
        queue.async {
            guard case .idle = self.state else { return }
            self.state = .connecting
            self.startConnection()
        }
    }

    private func startConnection() {
        dispatchPrecondition(condition: .onQueue(queue))
        // Arrange async callback; callback must re-enter queue before mutation.
    }

    func connectionFinished(with result: Result<Void, Error>) {
        queue.async {
            switch result {
            case .success:
                self.state = .connected
            case .failure(let error):
                self.state = .failed(error)
            }
        }
    }
}
```

All transitions occur on one serial queue, which makes state invariants easier to audit.

## Review checklist for a GCD API

- Which queue owns each mutable property?
- On which queue does each callback execute?
- Is completion always asynchronous or sometimes synchronous?
- Can `sync` re-enter the same queue?
- Is the chosen QoS tied to user intent?
- Can work be cancelled, and what does cancellation actually stop?
- Could the main thread block?
- Can submitted work grow without a bound?
- Are closures keeping screens or services alive unexpectedly?
- Would an actor or async function produce a clearer contract?

## Related

- [[05 - Protecting Shared State - Serial Queues and Barriers]]
- [[06 - DispatchGroup, DispatchWorkItem, and DispatchSemaphore]]
- [[11 - GCD and Modern Swift Concurrency]]

