import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: `Task { }` created on the main actor stays on the main actor.
/// `Task.detached` does not inherit isolation.
///
/// Swift Concurrency: `Task { }` vs `Task.detached { }`
///
/// Graduation: delete `import Concurrency101` and rewrite with `Task` / `Task.detached`.

print("=== ModernTaskVersusDetachedExample ===")
print("")

let finished = ExampleSupport.Flag()
let remaining = ExampleSupport.LockedCounter(2)

print("[1] hopping to the main actor, then starting both kinds of Task")

Concurrency101.Modern.updateUI {
    print("[2] on main actor (main: \(Thread.isMainThread))")

    Concurrency101.Modern.runUserRequestedWork {
        print("[3] Task(priority:) body — inherits isolation (main: \(ExampleSupport.currentlyOnMainThread()))")
        remaining.decrement()
    }

    Concurrency101.Modern.runDetachedFromCaller {
        print("[4] Task.detached body — no isolation (main: \(ExampleSupport.currentlyOnMainThread()))")
        remaining.decrement()
    }
}

print("[1b] caller continued")

ExampleSupport.pumpMainRunLoop(until: { remaining.get() == 0 })
finished.set()

print("")
print("If [3] is main and [4] is not, you have the lesson.")
print("Done.")
