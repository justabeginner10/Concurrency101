import Dispatch

extension Concurrency101.GCD {
    /// Blocking GCD APIs with names that should make you hesitate.
    ///
    /// `sync` and `wait` park **this thread**. They are not “more reliable
    /// async.” They deadlock the main queue if you wait for work that can only
    /// run on the thread you just parked.
    ///
    /// Swift Concurrency’s `await` *suspends a task*; it does not block a
    /// thread. That difference is the lesson. Prefer `async` + a completion,
    /// or `await`.
    ///
    /// There is **no** `blockThisThreadUntilFinished(on: .main)` convenience
    /// that hides `main.sync`. If you write it, you can deadlock. See
    /// <doc:Blocking>.
    public enum Blocking {
        /// Parks *this* thread until `work` has finished on `queue`.
        ///
        /// The caller waits: **yes**. That is the whole API.
        ///
        /// GCD: `queue.sync(execute:)`.
        ///
        /// Swift Concurrency: there is no good equivalent. `await` suspends;
        /// it does not block a thread.
        ///
        /// Do not use: from the main thread onto the main queue. From a serial
        /// queue onto itself. Inside Swift concurrent tasks in a way that
        /// prevents forward progress.
        ///
        /// Teaching trap: `sync` is not how you “make it thread-safe.” Isolation
        /// (serial lane / actor) is. Blocking is how you wait, and waiting can
        /// deadlock.
        ///
        /// ```swift
        /// let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.example.state")
        /// Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: lane) {
        ///     snapshot = value
        /// }
        /// ```
        ///
        /// Deadlock (never call this from the main thread):
        ///
        /// ```swift
        /// Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main) {
        ///     print("this never prints if called on the main thread")
        /// }
        /// ```
        ///
        /// - Parameters:
        ///   - queue: Where `work` runs.
        ///   - work: Work that must finish before this function returns.
        ///
        /// - SeeAlso: [sync(execute:)](https://developer.apple.com/documentation/dispatch/dispatchqueue/sync(execute:))
        public static func blockThisThreadUntilFinished(
            on queue: DispatchQueue,
            _ work: () -> Void
        ) {
            queue.sync(execute: work)
        }

        /// Parks *this* thread until `counter` is empty, or until `timeout`.
        ///
        /// The caller waits: **yes**.
        ///
        /// GCD: `DispatchGroup.wait(timeout:)`.
        ///
        /// Swift Concurrency: `await` a task group — without blocking a thread.
        ///
        /// Do not use: on the main thread. On a GCD worker that must also run
        /// the jobs you are waiting on (thread starvation / deadlock).
        ///
        /// ```swift
        /// let counter = Concurrency101.GCD.CompletionCounter()
        /// counter.beginOne()
        /// startJob { counter.endOne() }
        /// let outcome = Concurrency101.GCD.Blocking.blockThisThreadUntilAllJobsEnd(
        ///     counter,
        ///     timeout: .now() + 2
        /// )
        /// ```
        ///
        /// - Parameters:
        ///   - counter: The group you have been entering and leaving.
        ///   - timeout: When to stop waiting. Default waits forever.
        /// - Returns: `.success` if the count hit zero, `.timedOut` otherwise.
        ///
        /// - SeeAlso: [wait(timeout:)](https://developer.apple.com/documentation/dispatch/dispatchgroup/wait(timeout:))
        public static func blockThisThreadUntilAllJobsEnd(
            _ counter: CompletionCounter,
            timeout: DispatchTime = .distantFuture
        ) -> DispatchTimeoutResult {
            counter.group.wait(timeout: timeout)
        }
    }
}
