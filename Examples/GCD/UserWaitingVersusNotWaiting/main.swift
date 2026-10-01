import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: `.background` is lowest *urgency*, not “off the main thread.”
/// A tap the user is waiting on is `runUserRequestedWork` (`.userInitiated`).
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== UserWaitingVersusNotWaitingExample ===")
print("This is a naming drill, not a speed benchmark.")
print("QoS does not guarantee start time.")
print("")

let remaining = ExampleSupport.Flag()
let lock = NSLock()
var pending = 2
func markOneDone() {
    lock.lock()
    pending -= 1
    let done = pending == 0
    lock.unlock()
    if done { remaining.set() }
}

print("Refresh button (user is waiting) → runUserRequestedWork → qos: .userInitiated")
Concurrency101.GCD.runUserRequestedWork {
    print("  userInitiated hop running (main? \(Thread.isMainThread))")
    markOneDone()
}

print("Nightly cache prune (user is not waiting) → runWhenUserIsNotWaiting → qos: .background")
Concurrency101.GCD.runWhenUserIsNotWaiting {
    print("  background hop running (main? \(Thread.isMainThread))")
    markOneDone()
}

print("Caller already continued on this thread.")
ExampleSupport.pumpMainRunLoop(until: { remaining.get() })

print("")
print("Everyday English trap:")
print("  'do it in the background' ≠ DispatchQueue.global(qos: .background)")
print("  you usually meant runUserRequestedWork / .userInitiated")
print("")
print("GCD:")
print("    DispatchQueue.global(qos: .userInitiated).async { reloadFeed() }")
print("    DispatchQueue.global(qos: .background).async { pruneCache() }")
print("Swift Concurrency:")
print("    Task(priority: .userInitiated) { await reloadFeed() }")
print("    Task(priority: .background) { await pruneCache() }")
print("")
print("Done.")
