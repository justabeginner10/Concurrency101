extension Concurrency101.Modern {
    /// Runs `jobs` as child tasks of a task group. When **all** of them have
    /// finished, runs `finish`.
    ///
    /// The caller waits: **yes, as a task** — this function is `async` and
    /// does not return until every child and `finish` have completed. The
    /// thread is not blocked.
    ///
    /// Swift Concurrency: `await withTaskGroup(of: Void.self) { ... }`
    ///
    /// GCD: `DispatchGroup` + `async(group:)` + `notify` (notify does *not*
    /// wait at the call site). Here the `await` *is* the wait.
    ///
    /// Child tasks are **structured**: they cannot outlive this call.
    /// Cancellation of the parent cancels the children.
    ///
    /// Results are collected in **completion order**, not submission order.
    /// If you need named pairing, use ``runTwoAtOnce(_:_:)`` (`async let`).
    ///
    /// Use when: a dynamic number of independent loads, then continue.
    ///
    /// Do not use when: you have exactly two or three named pieces. Prefer
    /// `async let` / ``runTwoAtOnce(_:_:)``.
    ///
    /// ```swift
    /// await Concurrency101.Modern.runSeveralThenContinue(
    ///     jobs: [loadProfile, loadMessages, loadPrefs],
    ///     then: { await renderScreen() }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - jobs: Async bodies. Each becomes one child task.
    ///   - finish: Called once after every job has returned.
    ///
    /// - SeeAlso: [withTaskGroup](https://developer.apple.com/documentation/swift/withtaskgroup(of:returning:isolation:body:))
    public static func runSeveralThenContinue(
        jobs: [@Sendable () async -> Void],
        then finish: @escaping @Sendable () async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for job in jobs {
                group.addTask {
                    await job()
                }
            }
        }
        await finish()
    }

    /// Starts `first` and `second` immediately, then suspends until both
    /// have a value.
    ///
    /// Swift Concurrency: `async let`
    ///
    /// GCD: two `async` submissions plus a `DispatchGroup`.
    ///
    /// Use when: a fixed, known pair of independent loads.
    ///
    /// Do not use when: the count is dynamic. Use
    /// ``runSeveralThenContinue(jobs:then:)``.
    ///
    /// Teaching trap: `async let` starts the work at the `async let` line,
    /// not at the `await`. The `await` only joins.
    ///
    /// ```swift
    /// let (profile, feed) = await Concurrency101.Modern.runTwoAtOnce(
    ///     { await loadProfile() },
    ///     { await loadFeed() }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - first: First child. Starts immediately.
    ///   - second: Second child. Starts immediately.
    /// - Returns: Both results, in argument order.
    public static func runTwoAtOnce<A: Sendable, B: Sendable>(
        _ first: @escaping @Sendable () async -> A,
        _ second: @escaping @Sendable () async -> B
    ) async -> (A, B) {
        async let a = first()
        async let b = second()
        return await (a, b)
    }
}
