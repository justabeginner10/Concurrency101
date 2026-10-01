import Dispatch
import Foundation

extension Concurrency101.GCD {
    /// Runs `work` on the main queue and returns immediately. The current
    /// function does **not** wait.
    ///
    /// Use this to change UI (labels, images, navigation, SwiftUI state that
    /// must be driven from the main actor / main thread).
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchQueue.main.async(execute:)`
    ///
    /// Swift Concurrency: `@MainActor` on the function, `Task { @MainActor in }`,
    /// or `await MainActor.run { }`.
    ///
    /// Use when: setting anything the user sees.
    ///
    /// Do not use when: file I/O, JSON decode, image downsample, or networking.
    /// Those stall the UI because the main queue is serial and bound to the
    /// main thread.
    ///
    /// Teaching trap: “background work” is not the opposite of this helper.
    /// Off-main work still has to hop *back* here to touch UI.
    ///
    /// ```swift
    /// Concurrency101.GCD.updateUI {
    ///     titleLabel.text = title
    /// }
    /// ```
    ///
    /// Footgun — decode on the main queue:
    ///
    /// ```swift
    /// Concurrency101.GCD.updateUI {
    ///     let image = UIImage(data: hugeData) // hitch
    ///     imageView.image = image
    /// }
    /// ```
    ///
    /// - Parameter work: A closure that must touch UI. It runs later, on main.
    ///
    /// - SeeAlso: ``Concurrency101/GCD/updateUI(after:_:)``, ``Concurrency101/GCD/runUserRequestedWork(_:)``
    /// - SeeAlso: [DispatchQueue.main](https://developer.apple.com/documentation/dispatch/dispatchqueue/main)
    public static func updateUI(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    /// Runs `work` on the main queue no sooner than `delay` seconds from now,
    /// and returns immediately.
    ///
    /// The deadline is *eligibility*, not a reserved sleeping thread. If the
    /// main queue is busy, the work may run later than `delay`.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute:)`
    ///
    /// Swift Concurrency: `try await Task.sleep(for:)` then hop to the main
    /// actor.
    ///
    /// Use when: a one-shot UI delay (show a tooltip after a beat).
    ///
    /// Do not use when: calendar / wall-clock features (use date APIs), or
    /// repeating timers (use `DispatchSourceTimer` or a Swift `Task` loop — not
    /// chained `asyncAfter`, which drifts).
    ///
    /// ```swift
    /// Concurrency101.GCD.updateUI(after: 0.5) {
    ///     tooltip.isHidden = false
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - delay: Seconds until the work becomes eligible. Not a guarantee.
    ///   - work: UI work to run on the main queue.
    ///
    /// - SeeAlso: [asyncAfter](https://developer.apple.com/documentation/dispatch/dispatchqueue/asyncafter(deadline:execute:))
    public static func updateUI(after delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
