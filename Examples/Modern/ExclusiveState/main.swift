import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: an actor serializes mutation. Unstructured tasks on a shared `Int`
/// do not.
///
/// Swift Concurrency: `actor`
/// GCD: private serial `DispatchQueue`
///
/// Graduation: write `actor Counter { ... }` yourself.

print("=== ModernExclusiveStateExample ===")
print("")

let iterations = 400
let finished = ExampleSupport.Flag()

print("[1] actor: \(iterations) increments")

Concurrency101.Modern.runUserRequestedWork {
    let counter = Concurrency101.Modern.ExclusiveState(0)
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<iterations {
            group.addTask {
                await counter.modify { $0 += 1 }
            }
        }
    }
    let safe = await counter.snapshot()
    print("[2] actor result: \(safe) (expected \(iterations))")

    print("[3] racy unstructured tasks: \(iterations) unsynchronized += ")
    let unsync = UnsafeCounter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<iterations {
            group.addTask {
                unsync.value += 1
            }
        }
    }
    print("[4] racy result: \(unsync.value) (expected \(iterations); often less)")
    finished.set()
}

ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")

/// Unsynchronized box so the race is visible. Do not copy this into apps.
final class UnsafeCounter: @unchecked Sendable {
    var value = 0
}
