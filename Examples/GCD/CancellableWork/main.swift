import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: `DispatchWorkItem.cancel()` is cooperative. It skips work that has
/// not started. It does not abort a block that is already running.
///
/// GCD: `DispatchWorkItem`
/// Swift Concurrency: `Task.cancel()` + `Task.checkCancellation()`
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== CancellableWorkExample ===")
print("")

let finished = ExampleSupport.Flag()
let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.example.work")

print("--- Cancel before start ---")
let skipped = Concurrency101.GCD.makeCancellableWork {
    print("THIS SHOULD NOT PRINT")
}
skipped.cancel()
lane.async(execute: skipped)

print("--- Cancel after start (sleep still runs) ---")
let longItem = Concurrency101.GCD.makeCancellableWork {
    print("long item: started")
    Thread.sleep(forTimeInterval: 0.25)
    print("long item: finished sleep (cancel did not abort the running block)")
}

lane.async(execute: longItem)

DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
    print("cancelling long item while it is sleeping...")
    longItem.cancel()
}

longItem.notify(queue: .main) {
    print("notify: long item completed (isCancelled=\(longItem.isCancelled))")
    print("")
    print("GCD: let item = DispatchWorkItem { ... }; item.cancel(); queue.async(execute: item)")
    print("Swift: Task { ... }; task.cancel(); await Task.checkCancellation()")
    finished.set()
}

ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")
