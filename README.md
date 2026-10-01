# Concurrency101

**Learning only. Not for production. Not for App Store targets.**

`Concurrency101` wraps **Grand Central Dispatch** and **Swift Concurrency** behind names that describe *intent*. Every helper is a 1:1 mapping onto a real Apple API.

Two tracks, one package:

- `Concurrency101.GCD` — queues, QoS, barriers, groups, `sync`
- `Concurrency101.Modern` — tasks, actors, `await`, isolation

After you can explain each helper in Apple words, delete `import Concurrency101` and write `DispatchQueue`, `Task`, `@MainActor`, and `actor` yourself. If you keep this package in an app because “the names are nicer,” the package has failed.

A compiler warning is intentional:

```text
Concurrency101 is a teaching API. Use Dispatch or Swift Concurrency in real code.
```

## What problem this solves

GCD is hard because the words do not say what the caller should do, and because a queue is not a thread.

Swift Concurrency is hard for different reasons: `Task { }` inherits the current actor, `await` is not `sync`, cancellation is a flag, and actors re-enter at every `await`.

Existing wrappers still say `userInitiated`. Concurrency101 says `runUserRequestedWork` — on both tracks.

## Install

Local path (this repo):

```swift
dependencies: [
    .package(path: "/Users/adityaraj/Documents/Concurrency101"),
],
```

Then `import Concurrency101`. Requires Swift 5.9+, macOS 13 / iOS 16 / tvOS 16 / watchOS 9.

This package does **not** use Swift 6 `Sendable` on GCD closures on purpose. The Modern track *does* use `@Sendable`, because that is the lesson. Production Swift 6 code would tighten both. That is part of graduation.

## Demo app

An iOS / macOS workbench lives at `DemoApp/Concurrency101Demo.xcodeproj`. The landing page has two doors: **GCD** and **Swift Concurrency**. Each workbench shows a **glass console**. Each line is also `print`ed, so the Xcode console shows the same text.

Amber lines ran on the **main** thread. Cyan lines ran **off-main**. Toggle any snippet between Concurrency101 names and Apple names.

```bash
open /Users/adityaraj/Documents/Concurrency101/DemoApp/Concurrency101Demo.xcodeproj
```

Pick an iPhone simulator, press Run, choose a track, choose a lesson, tap **Run lesson**. Skip the freeze lessons unless you intend to hang the app (Stop in Xcode to recover).

## Two-axis mental model (GCD)

Queue type controls whether submitted work may overlap. Submission type controls whether the caller waits.

| Axis | GCD | Concurrency101.GCD |
|---|---|---|
| Overlap | serial vs concurrent | private serial lane vs shared concurrent lane |
| Waiting | `async` vs `sync` | run and return vs `Blocking` (avoid) |

## Two-axis mental model (Swift)

Isolation controls who may touch the state. `await` controls whether *this task* continues, without parking a thread.

| Axis | Swift | Concurrency101.Modern |
|---|---|---|
| Isolation | actor / `@MainActor` / detached | `ExclusiveState` / `waitForUI` / `runDetachedFromCaller` |
| Waiting | `await` vs unstructured `Task` | suspend this task vs start and return |

If it touches the UI, use `updateUI` / `waitForUI`. If the user asked and is waiting, use `runUserRequestedWork`, not `runWhenUserIsNotWaiting`.

## Rosetta table — GCD

| You mean | Call `Concurrency101.GCD` | Real GCD | Swift Concurrency |
|---|---|---|---|
| Change the UI, do not wait | `updateUI { }` | `DispatchQueue.main.async` | `Task { @MainActor in }` |
| Change the UI after a delay | `updateUI(after:) { }` | `main.asyncAfter` | `Task.sleep` then main actor |
| UI needs this *now* (rare, tiny) | `runForImmediateUI { }` | `.userInteractive` | `TaskPriority.high` |
| User tapped and is waiting | `runUserRequestedWork { }` | `.userInitiated` | `TaskPriority.userInitiated` |
| Progress the user may watch | `runMaintenanceWork { }` | `.utility` | `TaskPriority.utility` |
| User is not waiting | `runWhenUserIsNotWaiting { }` | `.background` | `TaskPriority.background` |
| One-at-a-time private lane | `makePrivateSerialLane` | serial `DispatchQueue(label:)` | `actor` |
| Overlapping private lane | `makeSharedConcurrentLane` | concurrent `DispatchQueue` | task group / many tasks |
| Submit, do not wait | `runOnLane` | `queue.async` | hop isolation |
| Exclusive write among concurrent reads | `runExclusiveWrite` | `async(flags: .barrier)` | actor / lock |
| Several jobs, then UI | `runSeveralThenContinue` | `DispatchGroup.notify` | `async let` / `TaskGroup` |
| Callback APIs, count completions | `CompletionCounter` | `enter` / `leave` / `notify` | continuations + task group |
| Cooperative cancel | `makeCancellableWork` | `DispatchWorkItem` | `Task.cancel` |
| Block this thread (avoid) | `Blocking.blockThisThreadUntilFinished` | `queue.sync` | do not block; `await` |
| Block this thread for a group (avoid) | `Blocking.blockThisThreadUntilAllJobsEnd` | `group.wait` | `await` the group of tasks |

## Rosetta table — Swift Concurrency

| You mean | Call `Concurrency101.Modern` | Real Swift | GCD cousin |
|---|---|---|---|
| Change the UI, do not wait | `updateUI { }` | `Task { @MainActor in }` | `main.async` |
| Change the UI, suspend until done | `await waitForUI { }` | `await MainActor.run` | *no honest equivalent* |
| Change the UI after a delay | `updateUI(after:) { }` | `Task.sleep` then main actor | `main.asyncAfter` |
| User tapped and is waiting | `runUserRequestedWork { }` | `Task(priority: .userInitiated)` | `global(.userInitiated).async` |
| Do not inherit this actor | `runDetachedFromCaller { }` | `Task.detached` | hop onto a global queue |
| One-at-a-time isolated state | `ExclusiveState` | `actor` | serial `DispatchQueue` |
| Several child tasks, then continue | `await runSeveralThenContinue` | `withTaskGroup` | `DispatchGroup.notify` |
| Two named loads at once | `await runTwoAtOnce` | `async let` | two async + a group |
| Delay without blocking a thread | `await pauseThisTask(for:)` | `Task.sleep` | not `Thread.sleep` |
| Cooperative cancel | `makeCancellableWork` | `Task.cancel` | `DispatchWorkItem.cancel` |
| Wrap a completion handler | `await waitForCallback` | `withCheckedContinuation` | the callback itself |
| Block this thread (avoid) | `Blocking.parkThisThreadUntilTaskFinishes` | semaphore around a Task | `queue.sync` |

### Everyday English traps

| Beginner says | They often type | They usually meant |
|---|---|---|
| “Do it in the background” | `.background` | `runUserRequestedWork` (`.userInitiated`) |
| “Async this” | — | GCD `async` = do not wait. Swift `async` = this function can suspend |
| “Sync this so it is safe” | `queue.sync` from main | isolation (serial lane / actor), not blocking |
| “Task { } from a button” | inherits `@MainActor` | `runDetachedFromCaller` if the work must leave UI |
| “Await is like sync” | — | `await` suspends the task; it does not park the thread |
| “Cancel stops it” | `task.cancel()` | cooperative — `Task.sleep` checks; CPU loops do not |

## Minimal snippet (GCD)

```swift
import Concurrency101

Concurrency101.GCD.runUserRequestedWork {
    let text = expensiveLoad()
    Concurrency101.GCD.updateUI {
        label.text = text
    }
}
```

## Minimal snippet (Swift)

```swift
import Concurrency101

Concurrency101.Modern.runDetachedFromCaller {
    let text = expensiveLoad()
    await Concurrency101.Modern.waitForUI {
        label.text = text
    }
}
```

## Blocking

`Blocking` names are ugly on purpose.

```swift
// Deadlock if called from the main thread:
Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main) {
    print("this never prints")
}

Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
    await Concurrency101.Modern.waitForUI {
        print("this never prints")
    }
}
```

`await` suspends a task. `sync` / `semaphore.wait` block a thread. Prefer `notify`, `await`, or a continuation.

## Tests and examples

```bash
cd /Users/adityaraj/Documents/Concurrency101
swift test
```

GCD lessons:

```bash
swift run GCDUpdateUIExample
swift run GCDUserWaitingVersusNotWaitingExample
swift run GCDPrivateSerialLaneExample
swift run GCDRunSeveralThenContinueExample
swift run GCDMissingEndOneExample
swift run GCDBarrierExample
swift run GCDCancellableWorkExample
```

Swift lessons:

```bash
swift run ModernUpdateUIExample
swift run ModernTaskVersusDetachedExample
swift run ModernExclusiveStateExample
swift run ModernTaskGroupExample
swift run ModernCancellationExample
swift run ModernContinuationExample
swift run ModernReentrancyExample
```

Hang-on-purpose (Ctrl+C to quit):

```bash
swift run GCDDeadlockOnPurposeExample
swift run ModernParkThreadOnPurposeExample
```

In Xcode, Product → Build Documentation for DocC articles.

## Graduation

Pick an example. Delete `import Concurrency101`. Rewrite it with Dispatch or with `Task` / `@MainActor` / `actor`.

Companion notes (Obsidian vault): `Obsidian-notes/Swift GCD/Notes/`, `Obsidian-notes/Swift Concurrency/Notes/`, and the spec `Obsidian-notes/Concurrency101/Concurrency101.md`.

## License

MIT. Teaching material. Not a production concurrency stack.
