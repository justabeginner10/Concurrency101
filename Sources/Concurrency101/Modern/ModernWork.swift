extension Concurrency101.Modern {
    /// Starts `work` as an unstructured task you can cancel.
    ///
    /// Returns a real `Task` so `cancel()`, `isCancelled`, and `value` stay
    /// visible. Graduation means writing `Task { }` yourself.
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `Task { await work() }`
    ///
    /// GCD: `DispatchWorkItem` + `cancel()`.
    ///
    /// Teaching trap: cancellation is **cooperative**. `task.cancel()` sets a
    /// flag. `Task.sleep` and `URLSession` check it. A tight CPU loop does
    /// not, unless you call `Task.checkCancellation()` or read
    /// `Task.isCancelled`.
    ///
    /// ```swift
    /// let task = Concurrency101.Modern.makeCancellableWork {
    ///     try await Concurrency101.Modern.pauseThisTask(for: 2)
    /// }
    /// task.cancel() // sleep throws CancellationError; work ends
    /// ```
    ///
    /// Already running CPU work:
    ///
    /// ```swift
    /// let task = Concurrency101.Modern.makeCancellableWork {
    ///     busyWaitTwoSeconds() // cancel() will not abort this
    /// }
    /// task.cancel()
    /// ```
    ///
    /// - Parameter work: The body of the task.
    /// - Returns: An unstructured `Task` you own.
    ///
    /// - SeeAlso: [Task.cancel()](https://developer.apple.com/documentation/swift/task/cancel())
    @discardableResult
    public static func makeCancellableWork(
        _ work: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            await work()
        }
    }

    /// Throws `CancellationError` if this task has been cancelled.
    ///
    /// Swift Concurrency: `try Task.checkCancellation()`
    ///
    /// Put this at loop boundaries and before expensive or irreversible
    /// steps. Most `await`s on system APIs already check.
    public static func throwIfCancelled() throws {
        try Task.checkCancellation()
    }

    /// Whether the current task has been cancelled.
    ///
    /// Swift Concurrency: `Task.isCancelled`
    ///
    /// Use when you need cleanup or a partial result instead of throwing.
    public static var isCurrentTaskCancelled: Bool {
        Task.isCancelled
    }
}
