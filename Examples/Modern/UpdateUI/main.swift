import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: heavy work must not inherit `@MainActor`. Hop back with `waitForUI`.
///
/// Swift Concurrency: `Task.detached` + `await MainActor.run`
/// GCD: `DispatchQueue.global(qos: .userInitiated).async` + `DispatchQueue.main.async`
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// `Task` / `@MainActor` / `actor`.

print("=== ModernUpdateUIExample ===")
print("Watch: 'caller continued' prints BEFORE 'decoded' and 'UI'.")
print("")

let finished = ExampleSupport.Flag()

print("[1] caller: submitting detached user-requested work")

Concurrency101.Modern.runDetachedFromCaller {
    print("[3] detached: fake decode (main: \(ExampleSupport.currentlyOnMainThread()) — want false)")
    try? await Concurrency101.Modern.pauseThisTask(for: 0.15)
    print("[4] decode finished, hopping to UI")
    await Concurrency101.Modern.waitForUI {
        print("[5] waitForUI: would set imageView.image here (main: \(ExampleSupport.currentlyOnMainThread()))")
        finished.set()
    }
}

print("[2] caller continued immediately (Task.detached does not wait)")

ExampleSupport.pumpMainRunLoop(until: { finished.get() })

print("")
print("Concurrency101.Modern:")
print("    Concurrency101.Modern.runDetachedFromCaller {")
print("        decode()")
print("        await Concurrency101.Modern.waitForUI { apply() }")
print("    }")
print("Apple Swift:")
print("    Task.detached {")
print("        decode()")
print("        await MainActor.run { apply() }")
print("    }")
print("")
print("Done.")
