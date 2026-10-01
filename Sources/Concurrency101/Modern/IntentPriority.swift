import Foundation

extension Concurrency101.Modern {
    /// Starts tiny work the UI needs *right now* at high priority, and returns
    /// immediately.
    ///
    /// This is **not** for touching `UIView` / SwiftUI view state. Commit to
    /// the screen with ``Concurrency101/Modern/updateUI(_:)`` or
    /// ``Concurrency101/Modern/waitForUI(_:)``.
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `Task(priority: .high) { await work() }`
    ///
    /// GCD: `DispatchQueue.global(qos: .userInteractive).async`
    ///
    /// Use when: preparing the next animation frame off the main actor.
    ///
    /// Do not use when: anything that takes more than a tiny amount of CPU.
    /// Highest priority competes with the UI and spends energy.
    ///
    /// Teaching trap: `Task { }` created on the main actor **inherits**
    /// `@MainActor`. This helper is unstructured and inherits the caller's
    /// actor isolation. To force work off the main actor, use
    /// ``Concurrency101/Modern/runDetachedFromCaller(_:)`` — and know why.
    ///
    /// ```swift
    /// Concurrency101.Modern.runForImmediateUI {
    ///     let frame = nextAnimationFrame()
    ///     await Concurrency101.Modern.waitForUI { apply(frame) }
    /// }
    /// ```
    ///
    /// - Parameter work: Tiny, UI-critical, non-UI-touching work.
    /// - Returns: The unstructured task.
    @discardableResult
    public static func runForImmediateUI(
        _ work: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task(priority: .high) {
            await work()
        }
    }

    /// Starts work the user asked for and is waiting on, then returns immediately.
    ///
    /// This is the hop beginners usually want when they say “do it in the
    /// background.” It is **not** `TaskPriority.background`.
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `Task(priority: .userInitiated) { await work() }`
    ///
    /// GCD: `DispatchQueue.global(qos: .userInitiated).async`
    ///
    /// Use when: open document, load the selected conversation, apply the
    /// filter they just chose.
    ///
    /// Do not use when: prefetch, backup, “might need later.” That is
    /// ``Concurrency101/Modern/runWhenUserIsNotWaiting(_:)``.
    ///
    /// Teaching trap: in everyday English “background” means “not the main
    /// actor.” In Swift, `.background` means *lowest urgency*. This helper is
    /// `.userInitiated`.
    ///
    /// ```swift
    /// Concurrency101.Modern.runUserRequestedWork {
    ///     let document = loadDocument()
    ///     await Concurrency101.Modern.waitForUI { show(document) }
    /// }
    /// ```
    ///
    /// - Parameter work: User-requested work that does not touch UI unless it
    ///   hops with `waitForUI` / `updateUI`.
    /// - Returns: The unstructured task.
    @discardableResult
    public static func runUserRequestedWork(
        _ work: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task(priority: .userInitiated) {
            await work()
        }
    }

    /// Starts longer useful work the user may notice (progress bar) but can
    /// continue doing other things, then returns immediately.
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `Task(priority: .utility) { await work() }`
    ///
    /// GCD: `DispatchQueue.global(qos: .utility).async`
    ///
    /// Use when: export, bulk import, download processing with visible progress.
    ///
    /// Do not use when: the user is blocked on the result in a modal they
    /// cannot dismiss. That is still
    /// ``Concurrency101/Modern/runUserRequestedWork(_:)``.
    ///
    /// Priority is not a deadline, a thread, or a start-time guarantee.
    ///
    /// ```swift
    /// Concurrency101.Modern.runMaintenanceWork {
    ///     await exportArchive()
    ///     await Concurrency101.Modern.waitForUI { hideProgress() }
    /// }
    /// ```
    ///
    /// - Parameter work: Longer work with optional visible progress.
    /// - Returns: The unstructured task.
    @discardableResult
    public static func runMaintenanceWork(
        _ work: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task(priority: .utility) {
            await work()
        }
    }

    /// Starts maintenance the user is **not** waiting for, then returns immediately.
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `Task(priority: .background) { await work() }`
    ///
    /// GCD: `DispatchQueue.global(qos: .background).async`
    ///
    /// Use when: cleanup, indexing, prefetch, cache pruning.
    ///
    /// Do not use when: anything the user just asked for. That is
    /// ``Concurrency101/Modern/runUserRequestedWork(_:)``.
    ///
    /// Teaching trap: this is the most misused word after “background.” Lowest
    /// urgency, not “off the main actor.”
    ///
    /// ```swift
    /// Concurrency101.Modern.runWhenUserIsNotWaiting {
    ///     await pruneCaches()
    /// }
    /// ```
    ///
    /// - Parameter work: Speculative or invisible maintenance.
    /// - Returns: The unstructured task.
    @discardableResult
    public static func runWhenUserIsNotWaiting(
        _ work: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task(priority: .background) {
            await work()
        }
    }
}
