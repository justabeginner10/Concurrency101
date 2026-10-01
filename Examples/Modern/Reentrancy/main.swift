import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: at every `await` inside an actor method, other callers may run.
/// Isolation is not a lock held across suspension.
///
/// Swift Concurrency: actor reentrancy
/// GCD: serial queues do not suspend; they deadlock if you `sync` onto self
///
/// Graduation: write the actor and the bug yourself.

print("=== ModernReentrancyExample ===")
print("")

let finished = ExampleSupport.Flag()
let counter = Concurrency101.Modern.ExclusiveState(0)

print("[1] first task: read, sleep, write current+1")
print("[2] second task: increment while the first is suspended")

Concurrency101.Modern.runUserRequestedWork {
    async let delayed: Int = counter.readAwaitWrite { current in
        print("[3] first saw \(current), now awaiting")
        try? await Concurrency101.Modern.pauseThisTask(for: 0.2)
        print("[4] first writing \(current + 1)")
        return current + 1
    }

    try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
    await counter.modify {
        $0 += 1
        print("[5] second incremented to \($0)")
    }

    _ = await delayed
    let final = await counter.snapshot()
    print("[6] final value: \(final) — often 1, not 2. The delayed write stomped.")
    finished.set()
}

ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")
