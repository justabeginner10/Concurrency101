import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: decode (or any heavy work) off the main queue, then hop to main for UI.
///
/// GCD: `DispatchQueue.global(qos: .userInitiated).async` + `DispatchQueue.main.async`
/// Swift Concurrency: `Task.detached` + `await MainActor.run`
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== UpdateUIExample ===")
print("Watch: 'caller continued' prints BEFORE 'decoded' and 'UI'.")
print("")

let finished = ExampleSupport.Flag()

print("[1] caller: submitting user-requested work")

Concurrency101.GCD.runUserRequestedWork {
    print("[3] runUserRequestedWork: fake decode (not on main: \(Thread.isMainThread ? "MAIN — wrong" : "background — good"))")
    Thread.sleep(forTimeInterval: 0.15)
    print("[4] decode finished, hopping to UI")
    Concurrency101.GCD.updateUI {
        print("[5] updateUI: would set imageView.image here (main: \(Thread.isMainThread))")
        finished.set()
    }
}

print("[2] caller continued immediately (async does not wait)")

ExampleSupport.pumpMainRunLoop(until: { finished.get() })

print("")
print("--- Contrast: the hitch ---")
print("Do not put decode inside updateUI. The main queue is serial; that stalls drawing.")
print("")
print("Concurrency101.GCD:")
print("    Concurrency101.GCD.runUserRequestedWork { decode(); Concurrency101.GCD.updateUI { apply() } }")
print("GCD:")
print("    DispatchQueue.global(qos: .userInitiated).async {")
print("        decode()")
print("        DispatchQueue.main.async { apply() }")
print("    }")
print("Swift Concurrency:")
print("    Task.detached(priority: .userInitiated) {")
print("        decode()")
print("        await MainActor.run { apply() }")
print("    }")
print("")
print("Done.")
