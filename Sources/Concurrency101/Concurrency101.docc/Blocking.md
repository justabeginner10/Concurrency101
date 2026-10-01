# Blocking APIs

@Metadata {
    @TitleHeading("Article")
}

``Concurrency101/GCD/Blocking`` and ``Concurrency101/Modern/Blocking`` exist so you can *see* `sync`, `wait`, and “semaphore around a Task”, run a deadlock on purpose, and then stop reaching for them.

## `sync` parks this thread

``Concurrency101/GCD/Blocking/blockThisThreadUntilFinished(on:_:)`` is `queue.sync`. The calling thread does not continue until `work` has finished.

Swift Concurrency’s `await` is different: it **suspends a task** and frees the thread to do other work. There is no honest 1:1 mapping. Prefer not blocking.

## Classic GCD deadlock

The main queue is serial and bound to the main thread. If the main thread is waiting for the main queue to run a block, that block can never start:

```swift
// Called from the main thread — hangs forever.
Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main) {
    print("this never prints")
}
```

GCD: `DispatchQueue.main.sync { }`.

## Classic Swift deadlock

Parking the main thread while waiting for MainActor work is the same shape:

```swift
Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
    await Concurrency101.Modern.waitForUI {
        print("this never prints")
    }
}
```

Run `swift run GCDDeadlockOnPurposeExample` or `swift run ModernParkThreadOnPurposeExample` only when you intend to hang the process. Do not put those calls in tests.

## Waiting for a group

``Concurrency101/GCD/Blocking/blockThisThreadUntilAllJobsEnd(_:timeout:)`` is `DispatchGroup.wait`. Do not call it on the main thread.

Prefer ``Concurrency101/GCD/runSeveralThenContinue(on:jobs:then:finishOn:)`` (`notify`) or ``Concurrency101/Modern/runSeveralThenContinue(jobs:then:)`` (`await` a task group).

## Semaphores are omitted from GCD

`DispatchSemaphore` is not wrapped as a friendly GCD helper. The only semaphore in this package is the ugly Swift anti-pattern ``Concurrency101/Modern/Blocking/parkThisThreadUntilTaskFinishes(_:)``.
