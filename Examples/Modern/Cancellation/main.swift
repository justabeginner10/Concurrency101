import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: `cancel()` sets a flag. `Task.sleep` checks it. A busy loop does not.
///
/// Swift Concurrency: `Task.cancel()` / `Task.checkCancellation()` / `Task.sleep`
/// GCD: `DispatchWorkItem.cancel()` (also cooperative)
///
/// Graduation: write `Task { }` and `task.cancel()` yourself.

print("=== ModernCancellationExample ===")
print("")

let finished = ExampleSupport.Flag()
let remaining = ExampleSupport.LockedCounter(2)

print("[1] cancelling a sleep — body should stop")
let sleeping = Concurrency101.Modern.makeCancellableWork {
    do {
        try await Concurrency101.Modern.pauseThisTask(for: 2)
        print("THIS SHOULD NOT PRINT (sleep completed)")
    } catch is CancellationError {
        print("[2] sleep threw CancellationError — cooperative cancel worked")
    } catch {
        print("unexpected \(error)")
    }
    remaining.decrement()
}
sleeping.cancel()

print("[3] cancelling a busy loop that never checks — body still finishes")
let busy = Concurrency101.Modern.makeCancellableWork {
    let deadline = Date().addingTimeInterval(0.2)
    while Date() < deadline {
        // no checkpoint
    }
    print("[4] busy loop finished even though the task was cancelled")
    remaining.decrement()
}
busy.cancel()

ExampleSupport.pumpMainRunLoop(until: { remaining.get() == 0 })
finished.set()
print("Done.")
