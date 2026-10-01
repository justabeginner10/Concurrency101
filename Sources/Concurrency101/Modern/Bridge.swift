extension Concurrency101.Modern {
    /// Suspends until a callback-style API calls `resume` on the continuation.
    ///
    /// This is how you wrap a completion-handler (or GCD `notify`) in `async`.
    /// Resume **exactly once**. Twice is a runtime crash. Never is a leak:
    /// the caller awaits forever.
    ///
    /// Swift Concurrency: `await withCheckedContinuation { ... }`
    ///
    /// GCD: `DispatchGroup.notify` / a completion handler you would
    /// `enter`/`leave` around.
    ///
    /// Use when: the SDK still speaks callbacks and you want `await`.
    ///
    /// Do not use when: the API already has an `async` overload. Call that.
    ///
    /// Teaching trap: the closure you pass to the callback API must call
    /// `continuation.resume` on every path — success, failure you ignore,
    /// cancel. Checked continuations log (and in some configs trap) if you
    /// forget. That is why this helper uses *checked*, not unsafe.
    ///
    /// ```swift
    /// let data = await Concurrency101.Modern.waitForCallback { continuation in
    ///     service.fetch { payload in
    ///         continuation.resume(returning: payload)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter body: You receive the continuation. Resume it once.
    /// - Returns: The value passed to `resume(returning:)`.
    ///
    /// - SeeAlso: [withCheckedContinuation](https://developer.apple.com/documentation/swift/withcheckedcontinuation(isolation:function:_:))
    public static func waitForCallback<T: Sendable>(
        _ body: (CheckedContinuation<T, Never>) -> Void
    ) async -> T {
        await withCheckedContinuation(body)
    }

    /// Like ``waitForCallback(_:)``, but the continuation can fail.
    ///
    /// Swift Concurrency: `try await withCheckedThrowingContinuation { ... }`
    ///
    /// Resume with `resume(returning:)` or `resume(throwing:)` — still
    /// exactly once.
    ///
    /// ```swift
    /// let data = try await Concurrency101.Modern.waitForThrowingCallback { continuation in
    ///     service.fetch { result in
    ///         switch result {
    ///         case .success(let value): continuation.resume(returning: value)
    ///         case .failure(let error): continuation.resume(throwing: error)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter body: You receive the throwing continuation. Resume it once.
    /// - Returns: The value passed to `resume(returning:)`.
    /// - Throws: The error passed to `resume(throwing:)`.
    public static func waitForThrowingCallback<T: Sendable>(
        _ body: (CheckedContinuation<T, Error>) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation(body)
    }
}
