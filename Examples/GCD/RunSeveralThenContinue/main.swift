import Foundation
import Concurrency101
import ExampleSupport

/// Lesson: `DispatchGroup.notify` continues when every job has finished.
/// The group does not run work; it only counts. The caller does not `wait`.
///
/// GCD: `DispatchGroup` + `async(group:)` + `notify`
/// Swift Concurrency: `async let` / `withTaskGroup`
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== RunSeveralThenContinueExample ===")
print("")

let finished = ExampleSupport.Flag()
let log = ExampleSupport.EventLog()

log.append("caller: submitting three loads")

Concurrency101.GCD.runSeveralThenContinue(
    jobs: [
        {
            Thread.sleep(forTimeInterval: 0.12)
            log.append("loaded profile")
        },
        {
            Thread.sleep(forTimeInterval: 0.05)
            log.append("loaded messages")
        },
        {
            Thread.sleep(forTimeInterval: 0.08)
            log.append("loaded prefs")
        },
    ],
    then: {
        log.append("screen ready (finish on main: \(Thread.isMainThread))")
        finished.set()
    }
)

log.append("caller continued (notify is async, not wait)")
ExampleSupport.pumpMainRunLoop(until: { finished.get() })

print("")
print("GCD:")
print("    let group = DispatchGroup()")
print("    queue.async(group: group) { loadProfile() }")
print("    group.notify(queue: .main) { renderScreen() }")
print("Swift Concurrency:")
print("    async let profile = loadProfile()")
print("    async let messages = loadMessages()")
print("    let _ = await (profile, messages)")
print("    await MainActor.run { renderScreen() }")
print("")
print("Done.")
