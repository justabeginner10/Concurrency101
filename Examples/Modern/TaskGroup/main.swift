import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: a task group is structured — the `await` does not return until
/// every child has finished. That is different from GCD `notify`.
///
/// Swift Concurrency: `withTaskGroup` / `async let`
/// GCD: `DispatchGroup.notify` (does not wait at the call site)
///
/// Graduation: write `withTaskGroup` / `async let` yourself.

print("=== ModernTaskGroupExample ===")
print("")

let finished = ExampleSupport.Flag()

print("[1] caller: awaiting runSeveralThenContinue")

Concurrency101.Modern.runUserRequestedWork {
    await Concurrency101.Modern.runSeveralThenContinue(
        jobs: [
            {
                try? await Concurrency101.Modern.pauseThisTask(for: 0.2)
                print("[2] loaded profile")
            },
            {
                try? await Concurrency101.Modern.pauseThisTask(for: 0.08)
                print("[3] loaded messages")
            },
            {
                try? await Concurrency101.Modern.pauseThisTask(for: 0.14)
                print("[4] loaded prefs")
            },
        ],
        then: {
            print("[5] screen ready — every child finished")
        }
    )

    let pair = await Concurrency101.Modern.runTwoAtOnce(
        { "left" },
        { "right" }
    )
    print("[6] async let pair: \(pair)")
    finished.set()
}

print("[1b] unstructured Task returned immediately; the group is still running")
ExampleSupport.pumpMainRunLoop(until: { finished.get() })
print("Done.")
