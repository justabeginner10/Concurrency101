import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: a private serial lane isolates mutable state. Two global hops do not.
///
/// GCD: `DispatchQueue(label:)` serial vs `DispatchQueue.global().async`
/// Swift Concurrency: `actor`
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== PrivateSerialLaneExample ===")
print("")

let iterations = 1_000
let finished = ExampleSupport.Flag()

print("--- Safe: serial lane ---")
let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.example.counter")
var safeCount = 0
let safeDone = DispatchGroup()

for _ in 0..<iterations {
    safeDone.enter()
    Concurrency101.GCD.runOnLane(lane) {
        safeCount += 1
        safeDone.leave()
    }
}

safeDone.notify(queue: .main) {
    print("serial increments: \(safeCount) (expected \(iterations))")
    print("")
    print("--- Racy: overlapping global hops ---")
    var racyCount = 0
    let racyDone = DispatchGroup()
    for _ in 0..<iterations {
        racyDone.enter()
        Concurrency101.GCD.runUserRequestedWork {
            racyCount += 1
            racyDone.leave()
        }
    }
    racyDone.notify(queue: .main) {
        print("unsynchronized increments: \(racyCount) (expected \(iterations); often less — data race)")
        print("")
        print("Concurrency101.GCD: makePrivateSerialLane + runOnLane")
        print("GCD:      DispatchQueue(label: \"com.example.counter\").async")
        print("Swift:    actor Counter { var value = 0; func increment() { value += 1 } }")
        finished.set()
    }
}

ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")
