import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: on a *custom concurrent* queue, a barrier is exclusive.
/// Barriers on `DispatchQueue.global()` are not (DEBUG assert in Concurrency101.GCD).
///
/// GCD: `queue.async(flags: .barrier)`
/// Swift Concurrency: `actor` or a lock around the write
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== BarrierExample ===")
print("Expected shape: two reads overlap, then write, then after.")
print("")

let finished = ExampleSupport.Flag()
let log = ExampleSupport.EventLog()
let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.example.cache")

Concurrency101.GCD.runOnLane(lane) {
    log.append("read A start")
    Thread.sleep(forTimeInterval: 0.15)
    log.append("read A end")
}
Concurrency101.GCD.runOnLane(lane) {
    log.append("read B start")
    Thread.sleep(forTimeInterval: 0.15)
    log.append("read B end")
}
Concurrency101.GCD.runExclusiveWrite(on: lane) {
    log.append("WRITE (exclusive)")
}
Concurrency101.GCD.runOnLane(lane) {
    log.append("read after write")
    Concurrency101.GCD.updateUI {
        print("")
        print("Order snapshot: \(log.snapshot())")
        print("")
        print("GCD: queue.async(flags: .barrier) { cache[key] = value }")
        print("Do not: runExclusiveWrite(on: .global()) — not exclusive.")
        finished.set()
    }
}

ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")
