import Dispatch

extension Concurrency101.GCD {
    /// Runs tiny work the UI needs *right now* (next frame, gesture follow-up)
    /// on a high-urgency global concurrent queue, and returns immediately.
    ///
    /// This is **not** for touching `UIView` / SwiftUI view state. Commit to
    /// the screen with ``Concurrency101/GCD/updateUI(_:)``.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchQueue.global(qos: .userInteractive).async`
    ///
    /// Swift Concurrency: `Task(priority: .userInteractive)` (or `.high`).
    ///
    /// Use when: preparing the next animation frame off the main thread.
    ///
    /// Do not use when: anything that takes more than a tiny amount of CPU.
    /// This class competes with the UI and spends energy.
    ///
    /// Teaching trap: highest QoS is not “more important, so always use it.”
    ///
    /// Two closures submitted this way **may overlap** and race on shared
    /// mutable state. Global queues do not isolate your data.
    ///
    /// ```swift
    /// Concurrency101.GCD.runForImmediateUI {
    ///     let frame = nextAnimationFrame()
    ///     Concurrency101.GCD.updateUI { apply(frame) }
    /// }
    /// ```
    ///
    /// - Parameter work: Tiny, UI-critical, non-UI-touching work.
    ///
    /// - SeeAlso: [Quality of Service](https://developer.apple.com/documentation/dispatch/dispatchqos)
    public static func runForImmediateUI(_ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInteractive).async(execute: work)
    }

    /// Runs work the user asked for and is waiting on, then returns immediately.
    ///
    /// This is the hop beginners usually want when they say “do it in the
    /// background.” It is **not** GCD’s `.background` class.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchQueue.global(qos: .userInitiated).async`
    ///
    /// Swift Concurrency: `Task(priority: .userInitiated)`, or
    /// `Task.detached(priority: .userInitiated)` for blocking work you must
    /// not run on an actor.
    ///
    /// Use when: open document, load the selected conversation, apply the
    /// filter they just chose.
    ///
    /// Do not use when: prefetch, backup, “might need later.” That is
    /// ``Concurrency101/GCD/runWhenUserIsNotWaiting(_:)``.
    ///
    /// Teaching trap: in everyday English “background” means “not the main
    /// thread.” In GCD, `.background` means *lowest urgency*. This helper is
    /// `.userInitiated`.
    ///
    /// Closures **may overlap**. Do not mutate shared state here without a
    /// private serial lane or an actor.
    ///
    /// ```swift
    /// Concurrency101.GCD.runUserRequestedWork {
    ///     let document = loadDocument()
    ///     Concurrency101.GCD.updateUI { show(document) }
    /// }
    /// ```
    ///
    /// - Parameter work: User-requested work that does not touch UI.
    public static func runUserRequestedWork(_ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async(execute: work)
    }

    /// Runs longer useful work the user may notice (progress bar) but can
    /// continue doing other things, then returns immediately.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchQueue.global(qos: .utility).async`
    ///
    /// Swift Concurrency: `Task(priority: .utility)`.
    ///
    /// Use when: export, bulk import, download processing with visible progress.
    ///
    /// Do not use when: the user is blocked on the result in a modal they
    /// cannot dismiss. That is still ``Concurrency101/GCD/runUserRequestedWork(_:)``.
    ///
    /// QoS is not a deadline, a thread, or a start-time guarantee.
    ///
    /// ```swift
    /// Concurrency101.GCD.runMaintenanceWork {
    ///     exportArchive()
    ///     Concurrency101.GCD.updateUI { hideProgress() }
    /// }
    /// ```
    ///
    /// - Parameter work: Longer non-UI work with optional visible progress.
    public static func runMaintenanceWork(_ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async(execute: work)
    }

    /// Runs maintenance the user is **not** waiting for, then returns immediately.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchQueue.global(qos: .background).async`
    ///
    /// Swift Concurrency: `Task(priority: .background)`.
    ///
    /// Use when: cleanup, indexing, prefetch, cache pruning.
    ///
    /// Do not use when: anything the user just asked for. That is
    /// ``Concurrency101/GCD/runUserRequestedWork(_:)``.
    ///
    /// Teaching trap: this is the most misused name in GCD. `.background` is
    /// lowest urgency, not “off the main thread.”
    ///
    /// ```swift
    /// Concurrency101.GCD.runWhenUserIsNotWaiting {
    ///     pruneCaches()
    /// }
    /// ```
    ///
    /// Footgun — Refresh button:
    ///
    /// ```swift
    /// // Wrong: the user is waiting.
    /// Concurrency101.GCD.runWhenUserIsNotWaiting { reloadFeed() }
    /// ```
    ///
    /// - Parameter work: Speculative or invisible maintenance.
    public static func runWhenUserIsNotWaiting(_ work: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async(execute: work)
    }
}
