extension Concurrency101.Modern {
    /// Starts work that does **not** inherit the caller's actor isolation,
    /// task-locals, or priority (unless you pass one).
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `Task.detached { await work() }`
    ///
    /// GCD: closest spirit is hopping onto a global queue from the main queue
    /// — you leave the main isolation domain on purpose.
    ///
    /// Use when: you are on the main actor and the work **must not** run there
    /// (heavy decode, blocking I/O), and a structured child is not available.
    ///
    /// Do not use when: you just need “background.” Prefer
    /// ``Concurrency101/Modern/runUserRequestedWork(_:)`` from a nonisolated
    /// context, or an `async` method that is not `@MainActor`.
    ///
    /// Teaching trap: you almost never want `Task.detached`. Created from
    /// `@MainActor`, `Task { }` stays on the main actor. Detached is how
    /// people accidentally escape isolation — or how they *mean* to escape
    /// it. Know which one you are doing.
    ///
    /// ```swift
    /// @MainActor
    /// func tap() {
    ///     Concurrency101.Modern.runDetachedFromCaller {
    ///         let image = decodeImage() // not on MainActor
    ///         await Concurrency101.Modern.waitForUI { imageView.image = image }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter work: Work that must not inherit the current actor.
    /// - Returns: The detached unstructured task.
    ///
    /// - SeeAlso: [Task.detached](https://developer.apple.com/documentation/swift/task/detached(priority:operation:)-21tdc)
    @discardableResult
    public static func runDetachedFromCaller(
        _ work: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task.detached {
            await work()
        }
    }
}
