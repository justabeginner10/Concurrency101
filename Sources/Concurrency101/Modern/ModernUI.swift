import Foundation

extension Concurrency101.Modern {
    /// Starts `work` on the main actor and returns immediately. The current
    /// function does **not** wait.
    ///
    /// Use this to change UI. This is the unstructured hop that matches GCD
    /// `DispatchQueue.main.async`: fire-and-forget.
    ///
    /// The caller waits: **no**. The returned `Task` can be awaited or cancelled.
    ///
    /// Swift Concurrency: `Task { @MainActor in work() }`
    ///
    /// GCD: `DispatchQueue.main.async(execute:)`
    ///
    /// Use when: you must hop to UI from a context that is not already on the
    /// main actor, and you do not need the hop to finish before continuing.
    ///
    /// Do not use when: you already are on the main actor and can just mutate
    /// UI, or when the next line depends on the UI work having happened. Then
    /// use ``Concurrency101/Modern/waitForUI(_:)``.
    ///
    /// Teaching trap: `Task { @MainActor in }` is **unstructured**. It outlives
    /// the current function. Prefer `await MainActor.run` (``waitForUI(_:)``)
    /// when the caller is already `async`.
    ///
    /// ```swift
    /// Concurrency101.Modern.updateUI {
    ///     titleLabel.text = title
    /// }
    /// ```
    ///
    /// - Parameter work: A closure that must touch UI. It runs later, on the
    ///   main actor.
    /// - Returns: The unstructured task that will run `work`.
    ///
    /// - SeeAlso: ``Concurrency101/Modern/waitForUI(_:)``, ``Concurrency101/Modern/updateUI(after:_:)``
    /// - SeeAlso: [MainActor](https://developer.apple.com/documentation/swift/mainactor)
    @discardableResult
    public static func updateUI(
        _ work: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            work()
        }
    }

    /// Suspends the **current task** until `work` has run on the main actor,
    /// then returns `work`'s value.
    ///
    /// The caller waits: **yes, as a task** — the thread is **not** blocked.
    /// That is the difference from GCD `sync`.
    ///
    /// Swift Concurrency: `await MainActor.run(body:)`
    ///
    /// GCD: there is no honest equivalent. `main.async` does not wait;
    /// `main.sync` waits by parking the thread and can deadlock.
    ///
    /// Use when: the next line needs the UI update (or its result) to have
    /// happened, and you are already in an `async` function.
    ///
    /// Do not use when: you are not in an async context and are tempted to
    /// wrap this in a semaphore. That is
    /// ``Concurrency101/Modern/Blocking/parkThisThreadUntilTaskFinishes(_:)``.
    ///
    /// Teaching trap: “await means wait, so it is like sync.” `await` suspends
    /// this task and lets the thread run other work. `sync` parks the thread.
    ///
    /// ```swift
    /// await Concurrency101.Modern.waitForUI {
    ///     titleLabel.text = title
    /// }
    /// ```
    ///
    /// - Parameter work: UI work. Runs on the main actor.
    /// - Returns: Whatever `work` returns.
    ///
    /// - SeeAlso: [MainActor.run](https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:))
    public static func waitForUI<T: Sendable>(
        _ work: @escaping @MainActor @Sendable () -> T
    ) async -> T {
        await MainActor.run(body: work)
    }

    /// Starts a task that sleeps for `delay` seconds (suspending, not
    /// blocking a thread), then runs `work` on the main actor.
    ///
    /// The caller waits: **no**.
    ///
    /// Swift Concurrency: `try await Task.sleep(for:)` then `await MainActor.run`.
    ///
    /// GCD: `DispatchQueue.main.asyncAfter(deadline:)`.
    ///
    /// Use when: a one-shot UI delay (show a tooltip after a beat).
    ///
    /// Do not use when: calendar / wall-clock features, or a repeating timer
    /// you need to cancel cleanly — loop with `Task.sleep` inside a `Task`
    /// you own, and cancel that task.
    ///
    /// Teaching trap: `Task.sleep` is cancellation-aware. If the returned
    /// task is cancelled during the sleep, `work` does not run.
    ///
    /// ```swift
    /// Concurrency101.Modern.updateUI(after: 0.5) {
    ///     tooltip.isHidden = false
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - delay: Seconds to suspend before the UI work becomes eligible.
    ///   - work: UI work to run on the main actor.
    /// - Returns: The unstructured task performing the delay and hop.
    ///
    /// - SeeAlso: [Task.sleep](https://developer.apple.com/documentation/swift/task/sleep(for:clock:))
    @discardableResult
    public static func updateUI(
        after delay: TimeInterval,
        _ work: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            try? await pauseThisTask(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
    }
}
