import Foundation

struct LessonPrediction: Hashable {
    var prompt: String
    var choices: [String]
    var correctIndex: Int
}

enum LessonPredictions {
    static func prediction(for scenarioID: String) -> LessonPrediction? {
        table[scenarioID]
    }

    private static let table: [String: LessonPrediction] = [
        "modern-decode-ui": predict(
            "After you submit the decode, the caller…",
            "continues immediately",
            "waits until waitForUI runs"
        ),
        "modern-delayed-ui": predict(
            "The delay…",
            "suspends a task. It does not park a thread",
            "blocks the main thread for the whole wait"
        ),
        "modern-priority": predict(
            "A Refresh tap should run as…",
            "user-initiated work, not background",
            "background work, so it stays off the fast path"
        ),
        "modern-immediate": predict(
            "Tiny next-frame UI work…",
            "still goes through the main actor",
            "may touch the screen from any thread"
        ),
        "modern-maintenance": predict(
            "Maintenance work is for…",
            "longer work the user is not tap-waiting on",
            "the same urgency as a button tap"
        ),
        "modern-detached": predict(
            "Task { } started on the main actor…",
            "stays on the main actor. Detached leaves",
            "always hops off, the same as Task.detached"
        ),
        "modern-actor": predict(
            "Unsynchronized += from several tasks…",
            "can lose updates",
            "is safe because the tasks are structured"
        ),
        "modern-group": predict(
            "await on the group…",
            "returns only after every child finishes",
            "returns immediately, the way GCD notify does"
        ),
        "modern-async-let": predict(
            "The two loads start…",
            "at the async let lines, before await",
            "only when each value is awaited"
        ),
        "modern-cancel-sleep": predict(
            "Cancelling a sleeping task…",
            "ends the sleep. Sleep checks the flag",
            "does nothing until the sleep finishes"
        ),
        "modern-cancel-busy": predict(
            "Cancelling a tight CPU loop…",
            "does nothing unless the loop checks",
            "kills the thread"
        ),
        "modern-continuation": predict(
            "The callback must resume…",
            "exactly once",
            "as many times as the callback fires"
        ),
        "modern-reentrancy": predict(
            "Across await, the actor…",
            "can run another call before this one resumes",
            "holds a lock so the cache cannot change"
        ),
        "modern-await-vs-block": predict(
            "await on this sleep…",
            "lets the caller continue",
            "parks a thread until the sleep ends"
        ),
        "modern-deadlock": predict(
            "Parking the main thread while waiting for the main actor…",
            "never returns",
            "runs the main-actor work inline"
        ),
        "update-ui": predict(
            "After you submit the decode, the caller…",
            "continues immediately",
            "waits until the main-queue UI block runs"
        ),
        "delayed-ui": predict(
            "The delay…",
            "is the earliest the block may run",
            "sleeps a thread for the whole interval"
        ),
        "qos-names": predict(
            "A Refresh tap should be…",
            "user-initiated, not .background",
            ".background, so it stays off the fast queues"
        ),
        "immediate-ui": predict(
            "Tiny next-frame UI work…",
            "still goes through the main queue",
            "may touch the screen from a global queue"
        ),
        "maintenance": predict(
            "Maintenance work is for…",
            "longer work the user is not tap-waiting on",
            "the same urgency as a button tap"
        ),
        "serial-race": predict(
            "Unsynchronized += on a concurrent pool…",
            "can lose updates",
            "is safe because += is one line"
        ),
        "overlap": predict(
            "On a concurrent lane, a second item…",
            "can run while the first is still in flight",
            "waits until the first item finishes"
        ),
        "barrier": predict(
            "A barrier write…",
            "waits, then runs with nothing overlapping it",
            "is just another concurrent read"
        ),
        "group-notify": predict(
            "group.notify…",
            "runs later. The caller does not wait",
            "blocks the caller until the group is empty"
        ),
        "missing-leave": predict(
            "If leave is forgotten…",
            "finish never runs",
            "the group cancels the work"
        ),
        "enter-leave": predict(
            "endOne belongs…",
            "on every completion path",
            "only on the success path"
        ),
        "work-item": predict(
            "Cancel before the item starts…",
            "skips the body",
            "runs the body, then stops it"
        ),
        "sync-safe": predict(
            "sync on a background lane…",
            "parks the caller until the work returns",
            "returns immediately, like async"
        ),
        "wait-timeout": predict(
            "An unbalanced group.wait…",
            "times out. The work still needs leave",
            "cancels the grouped work"
        ),
        "deadlock": predict(
            "main.sync from the main queue…",
            "never returns",
            "runs the block inline and returns"
        ),
    ]

    private static func predict(_ prompt: String, _ correct: String, _ wrong: String) -> LessonPrediction {
        LessonPrediction(prompt: prompt, choices: [correct, wrong], correctIndex: 0)
    }
}
