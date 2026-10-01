import Dispatch

extension Concurrency101.GCD {
    /// Starts `jobs` on `queue` (they may overlap if `queue` is concurrent).
    /// When **all** of them have finished, runs `finish` on `finishQueue`.
    ///
    /// The caller waits: **no**. `finish` is scheduled with `notify`, not
    /// `wait`. Empty `jobs` still invokes `finish`.
    ///
    /// GCD: `DispatchGroup` + `queue.async(group:)` + `group.notify(queue:)`.
    ///
    /// Swift Concurrency: `async let`, `withTaskGroup`, then hop to
    /// `@MainActor` if needed.
    ///
    /// The group does not run work. It only counts. Jobs default to a global
    /// *user-initiated* queue — never the main queue — so you do not
    /// accidentally serialize UI work. `finish` defaults to main because the
    /// usual next step is UI.
    ///
    /// Use when: several independent loads, then render the screen.
    ///
    /// Do not use when: the jobs are callback-style APIs that return before
    /// they finish. Use ``CompletionCounter`` (`enter` / `leave`) instead.
    ///
    /// ```swift
    /// Concurrency101.GCD.runSeveralThenContinue(
    ///     jobs: [loadProfile, loadMessages, loadPrefs],
    ///     then: { renderScreen() }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - queue: Where jobs run. Default: `DispatchQueue.global(qos: .userInitiated)`.
    ///   - jobs: Synchronous bodies. Each is one group member.
    ///   - finish: Called once when every job has returned.
    ///   - finishQueue: Where `finish` runs. Default: main.
    ///
    /// - SeeAlso: [DispatchGroup](https://developer.apple.com/documentation/dispatch/dispatchgroup)
    public static func runSeveralThenContinue(
        on queue: DispatchQueue = .global(qos: .userInitiated),
        jobs: [() -> Void],
        then finish: @escaping () -> Void,
        finishOn finishQueue: DispatchQueue = .main
    ) {
        let group = DispatchGroup()
        for job in jobs {
            queue.async(group: group, execute: job)
        }
        group.notify(queue: finishQueue, execute: finish)
    }

    /// Counts in-flight callback-style operations, then continues when the
    /// count returns to zero.
    ///
    /// This is a thin box around `DispatchGroup`. The GCD names you must
    /// recognize in real code are `enter`, `leave`, and `notify`.
    ///
    /// | Concurrency101.GCD | GCD |
    /// |---|---|
    /// | `beginOne()` | `enter()` |
    /// | `endOne()` | `leave()` |
    /// | `whenAllHaveEnded` | `notify` |
    ///
    /// Failure modes:
    /// - Missing `endOne()` → `finish` never runs.
    /// - Extra `endOne()` → runtime trap.
    /// - Calling `endOne()` before the real async work finishes → `finish` too early.
    ///
    /// Swift Concurrency: wrap each callback in `withCheckedContinuation`,
    /// then a task group.
    ///
    /// ```swift
    /// let counter = Concurrency101.GCD.CompletionCounter()
    /// counter.beginOne()
    /// service.fetch { result in
    ///     defer { counter.endOne() }
    ///     handle(result)
    /// }
    /// counter.whenAllHaveEnded {
    ///     renderScreen()
    /// }
    /// ```
    public final class CompletionCounter {
        let group = DispatchGroup()

        /// Creates an empty counter (count zero). `whenAllHaveEnded` would
        /// run `finish` immediately until you `beginOne`.
        public init() {}

        /// Increments the in-flight count. Pair with exactly one ``endOne()``
        /// on every completion path.
        ///
        /// GCD: `DispatchGroup.enter()`.
        public func beginOne() {
            group.enter()
        }

        /// Decrements the in-flight count.
        ///
        /// GCD: `DispatchGroup.leave()`.
        ///
        /// Calling this more times than ``beginOne()`` traps at runtime.
        /// Concurrency101.GCD does not catch that trap — seeing it is the lesson.
        public func endOne() {
            group.leave()
        }

        /// Runs `finish` on `queue` when the count is zero. Does **not** block
        /// the registering thread.
        ///
        /// GCD: `DispatchGroup.notify(queue:execute:)`.
        ///
        /// - Parameters:
        ///   - queue: Where `finish` runs. Default: main.
        ///   - finish: Called once when every `beginOne` has a matching `endOne`.
        public func whenAllHaveEnded(
            on queue: DispatchQueue = .main,
            _ finish: @escaping () -> Void
        ) {
            group.notify(queue: queue, execute: finish)
        }
    }
}
