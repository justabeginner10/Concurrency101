# DispatchGroup, DispatchWorkItem, and DispatchSemaphore

These types solve different coordination problems:

| Type | Main question |
|---|---|
| `DispatchGroup` | When have all of these operations completed? |
| `DispatchWorkItem` | How can this submitted unit have identity, notification, flags, and cooperative cancellation? |
| `DispatchSemaphore` | How can access be counted or a thread be blocked until a signal occurs? |

## DispatchGroup

A group tracks a collection of asynchronous operations as one logical unit. It does not execute work itself.

### Queue-managed group membership

```swift
let group = DispatchGroup()
let queue = DispatchQueue.global(qos: .userInitiated)

queue.async(group: group) {
    loadProfile()
}

queue.async(group: group) {
    loadMessages()
}

queue.async(group: group) {
    loadPreferences()
}

group.notify(queue: .main) {
    renderScreen()
}
```

`notify` schedules its closure when the tracked work has completed. It does not block the thread registering the notification.

### Manual membership for callback APIs

```swift
let group = DispatchGroup()

group.enter()
profileService.fetch { result in
    defer { group.leave() }
    handleProfile(result)
}

group.enter()
messageService.fetch { result in
    defer { group.leave() }
    handleMessages(result)
}

group.notify(queue: .main) {
    renderScreen()
}
```

Every `enter()` must be balanced by exactly one `leave()` on every completion path.

Failure modes:

- missing `leave()` → notification never fires
- extra `leave()` → runtime failure
- calling `leave()` before the true async operation finishes → group completes too early
- mutating shared results from callbacks without isolation → data race

### Waiting and timeouts

```swift
let outcome = group.wait(timeout: .now() + 2)

switch outcome {
case .success:
    print("completed")
case .timedOut:
    print("still running")
}
```

`wait` blocks the calling thread. A timeout stops waiting; it does **not** cancel the grouped operations. Never wait on the main thread for UI-related work.

Prefer `notify` or modern `async` composition.

### Groups do not collect values or errors

A group only tracks completion. If operations produce results, store them in a properly isolated container or design an aggregation layer. Do not append concurrently to an ordinary array.

## DispatchWorkItem

```swift
let item = DispatchWorkItem(qos: .utility) {
    rebuildSearchIndex()
}

item.notify(queue: .main) {
    statusLabel.text = "Index ready"
}

workerQueue.async(execute: item)
```

Useful features:

- explicit representation of a work unit
- cancellation state
- completion notification
- QoS and work-item flags
- group integration

### Cooperative cancellation

```swift
var item: DispatchWorkItem!

item = DispatchWorkItem {
    for record in records {
        if item.isCancelled {
            return
        }

        index(record)
    }
}

queue.async(execute: item)
item.cancel()
```

`cancel()` records cancellation intent. It cannot safely terminate arbitrary executing code. The closure must check cancellation at useful points and clean up before returning.

Cancellation also does not automatically propagate to network requests, file operations, or other nested work. The work item must explicitly cancel those resources where supported.

### Debouncing with work items

```swift
final class SearchCoordinator {
    private var pendingItem: DispatchWorkItem?

    func queryChanged(to query: String) {
        pendingItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.beginSearch(query)
        }

        pendingItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(300),
            execute: item
        )
    }
}
```

This suppresses pending work items. If an earlier search has already begun, cancelling its scheduling item does not magically cancel that search.

## DispatchSemaphore

A semaphore contains a counter.

- `wait()` attempts to decrement it. If the count is zero, the calling thread blocks.
- `signal()` increments it and wakes a waiter when applicable.

### Limiting concurrency

```swift
let limit = DispatchSemaphore(value: 3)
let group = DispatchGroup()
let queue = DispatchQueue.global(qos: .utility)

for file in files {
    group.enter()
    queue.async {
        limit.wait()
        defer {
            limit.signal()
            group.leave()
        }

        process(file)
    }
}
```

At most three blocks pass the semaphore simultaneously.

However, all remaining submitted blocks may occupy threads while waiting. With a large input, a bounded producer, `OperationQueue`, or structured task-group algorithm can be more resource-efficient.

### Binary semaphore

```swift
let semaphore = DispatchSemaphore(value: 1)
```

This can behave like a mutex, but lacks the clear ownership and diagnostics of a dedicated lock and can be accidentally over-signalled. It is rarely the best default for state protection.

### Converting async to sync: usually a warning sign

```swift
let semaphore = DispatchSemaphore(value: 0)
var output: Result<Data, Error>?

fetchData { result in
    output = result
    semaphore.signal()
}

semaphore.wait() // Blocks a thread and may deadlock
```

Risks:

- called on the same queue needed for the callback → deadlock
- called on main → frozen UI
- many callers → blocked-thread exhaustion
- priority inversion
- awkward timeout, cancellation, and error propagation

Keep the API asynchronous or use a checked continuation when adapting a callback API to Swift concurrency.

### Timeout

```swift
if semaphore.wait(timeout: .now() + 1) == .timedOut {
    // Waiting stopped; the underlying producer was not cancelled.
}
```

As with groups, timeout changes the waiter’s behavior, not the producer’s lifecycle.

## Choosing the right primitive

```text
Need to know when N operations finish?
    -> DispatchGroup

Need identity/notification/cooperative cancellation for one queued closure?
    -> DispatchWorkItem

Need a small count of simultaneous resource users?
    -> Semaphore, or preferably a higher-level bounded design

Need to protect mutable state?
    -> Actor, serial queue, barrier queue, or lock
```

## Related

- [[05 - Protecting Shared State - Serial Queues and Barriers]]
- [[09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging]]
- [[11 - GCD and Modern Swift Concurrency]]

## Official references

- [DispatchGroup](https://developer.apple.com/documentation/dispatch/dispatchgroup)
- [DispatchWorkItem](https://developer.apple.com/documentation/dispatch/dispatchworkitem)
- [DispatchSemaphore](https://developer.apple.com/documentation/dispatch/dispatchsemaphore)

