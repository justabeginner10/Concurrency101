import Foundation

extension Concurrency101.Modern {
    /// Suspends this task for about `seconds`, then resumes. Does **not**
    /// block a thread.
    ///
    /// Swift Concurrency: `try await Task.sleep(for: .seconds(seconds))`
    ///
    /// GCD: `asyncAfter` is the closest *delay*; `Thread.sleep` is the closest
    /// *wait*, and is the wrong tool inside a task.
    ///
    /// Throws `CancellationError` if the task is cancelled during the sleep.
    /// That is a feature: cancellation is cooperative, and `Task.sleep`
    /// checks the flag for you.
    ///
    /// Use when: you need a delay inside structured work (retry backoff, a
    /// pause in a loop).
    ///
    /// Do not use when: you mean `Thread.sleep` / `queue.sync`. Those park
    /// threads. Never sleep a thread inside the cooperative thread pool.
    ///
    /// ```swift
    /// try await Concurrency101.Modern.pauseThisTask(for: 0.25)
    /// ```
    ///
    /// - Parameter seconds: Duration to suspend.
    ///
    /// - SeeAlso: [Task.sleep(for:clock:)](https://developer.apple.com/documentation/swift/task/sleep(for:clock:))
    public static func pauseThisTask(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    /// Suspends briefly so other work at the same priority can run.
    ///
    /// Swift Concurrency: `await Task.yield()`
    ///
    /// Use when: a long CPU loop on a task should give others a chance, or
    /// you need a cancellation checkpoint without a real delay.
    ///
    /// Do not use when: you needed `Task.sleep` (a real delay) or you are
    /// trying to “fix” a race by yielding. Fix the isolation instead.
    ///
    /// - SeeAlso: [Task.yield()](https://developer.apple.com/documentation/swift/task/yield())
    public static func letOthersRun() async {
        await Task.yield()
    }
}
