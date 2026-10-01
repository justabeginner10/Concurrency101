import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: wrap a completion handler with a checked continuation.
/// Resume exactly once.
///
/// Swift Concurrency: `withCheckedContinuation`
/// GCD: the callback you would `enter`/`leave` around
///
/// Graduation: write `await withCheckedContinuation` yourself.

print("=== ModernContinuationExample ===")
print("")

let finished = ExampleSupport.Flag()

print("[1] wrapping a fake GCD callback")

Concurrency101.Modern.runUserRequestedWork {
    let text = await Concurrency101.Modern.waitForCallback { continuation in
        Concurrency101.GCD.runUserRequestedWork {
            print("[2] callback fired off-main")
            continuation.resume(returning: "payload")
        }
    }
    print("[3] awaited callback value: \(text)")
    finished.set()
}

print("[1b] caller continued")
ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")
