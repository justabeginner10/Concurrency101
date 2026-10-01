import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: every `beginOne()` (`enter`) needs exactly one `endOne()` (`leave`).
/// Missing `leave` means `notify` never fires. Extra `leave` traps at runtime
/// (this example does not demonstrate the trap).
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== MissingEndOneExample ===")
print("Simulates a callback API where we forget group.leave().")
print("finish will NOT run. The process still exits after a timeout.")
print("")

let timedOut = ExampleSupport.Flag()
let finishRan = ExampleSupport.Flag()

let counter = Concurrency101.GCD.CompletionCounter()
counter.beginOne()
print("beginOne() — GCD enter(). In-flight count is 1.")

counter.whenAllHaveEnded {
    print("whenAllHaveEnded — this should NOT print")
    finishRan.set()
}

print("Forgot endOne() / leave(). Waiting briefly to prove finish stays silent...")

let deadline = Date().addingTimeInterval(0.6)
while Date() < deadline {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    if finishRan.get() { break }
}

if finishRan.get() {
    print("Unexpected: finish ran.")
} else {
    print("Confirmed: finish did not run.")
    print("Fix: defer { counter.endOne() } on every callback path.")
}

print("")
print("GCD:")
print("    group.enter()")
print("    service.fetch { result in")
print("        defer { group.leave() }")
print("        handle(result)")
print("    }")
print("    group.notify(queue: .main) { render() }")
print("")
timedOut.set()
print("Done (process exits; group still unbalanced on purpose).")
