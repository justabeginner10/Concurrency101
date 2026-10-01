import Dispatch

extension Concurrency101.Modern {
    /// Blocking anti-patterns with names that should make you hesitate.
    ///
    /// `await` suspends a task. These APIs park **this thread**. Mixing them
    /// with Swift Concurrency is how you deadlock the main actor: the thread
    /// is waiting for a task that can only run on the thread you just parked.
    ///
    /// Prefer `await` on a `Task`, a task group, or ``waitForCallback(_:)``.
    public enum Blocking {
        /// Parks *this* thread until `work`'s task has finished.
        ///
        /// The caller waits: **yes**. That is the whole API. This is the
        /// classic “wait for async with a semaphore” anti-pattern.
        ///
        /// Swift Concurrency: **do not do this.** There is no good equivalent
        /// of GCD `sync` for tasks. Use `await`.
        ///
        /// GCD: `DispatchSemaphore.wait` around work, or `queue.sync`.
        ///
        /// Do not use: from the main thread when `work` needs the main actor.
        /// From a cooperative-pool thread that Swift still needs in order to
        /// run `work` (thread-pool exhaustion).
        ///
        /// Teaching trap: “I am not in an async function, so I will block
        /// until the Task finishes.” That is how you freeze UI and starve the
        /// runtime. Make the caller `async` instead.
        ///
        /// ```swift
        /// // Safe only because work never needs the parked thread:
        /// Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
        ///     try? await Concurrency101.Modern.pauseThisTask(for: 0.1)
        /// }
        /// ```
        ///
        /// Deadlock (never call this from the main thread if work hops to UI):
        ///
        /// ```swift
        /// Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
        ///     await Concurrency101.Modern.waitForUI {
        ///         print("this never prints if called on the main thread")
        ///     }
        /// }
        /// ```
        ///
        /// - Parameter work: Async work that must finish before this function
        ///   returns.
        public static func parkThisThreadUntilTaskFinishes(
            _ work: @escaping @Sendable () async -> Void
        ) {
            let gate = DispatchSemaphore(value: 0)
            Task.detached {
                await work()
                gate.signal()
            }
            gate.wait()
        }
    }
}
