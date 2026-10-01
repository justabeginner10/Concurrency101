extension Concurrency101.Modern {
    /// A teaching `actor`: one-at-a-time isolation for a single `Sendable` value.
    ///
    /// This is the Swift Concurrency counterpart of
    /// ``Concurrency101/GCD/makePrivateSerialLane(label:qos:)``. The compiler
    /// enforces that you only touch `value` through the actor.
    ///
    /// Swift Concurrency: `actor`.
    ///
    /// GCD: a private serial `DispatchQueue` plus the discipline never to
    /// touch the state off-queue.
    ///
    /// Use when: one object's mutable state must not be accessed from two
    /// tasks at once.
    ///
    /// Do not use when: the state is UI. UI belongs on `@MainActor`, not a
    /// custom actor you then have to hop back from.
    ///
    /// Teaching trap — **reentrancy**: at every `await` *inside* an actor
    /// method, other callers of this actor may run. Isolation is not a lock
    /// held across suspension. See ``readAwaitWrite(_:)``.
    ///
    /// ```swift
    /// let counter = Concurrency101.Modern.ExclusiveState(0)
    /// await counter.modify { $0 += 1 }
    /// let n = await counter.snapshot()
    /// ```
    ///
    /// Graduation: delete this type and write `actor Counter { ... }` yourself.
    public actor ExclusiveState<Value: Sendable> {
        /// The isolated value. Isolated to this actor — you cannot read it
        /// from outside without `await`.
        public private(set) var value: Value

        /// Creates an actor that owns `value`.
        ///
        /// - Parameter value: Initial state. Must be `Sendable` because it
        ///   crosses into the actor.
        public init(_ value: Value) {
            self.value = value
        }

        /// Returns a copy of the current value. Does not suspend unless the
        /// actor is busy (the `await` is at the call site).
        ///
        /// Swift Concurrency: an actor-isolated getter.
        public func snapshot() -> Value {
            value
        }

        /// Replaces the value. One-at-a-time with every other isolated method.
        public func replace(_ newValue: Value) {
            value = newValue
        }

        /// Mutates the value without suspending. Safe: no `await` inside, so
        /// no other caller can interleave.
        ///
        /// ```swift
        /// await counter.modify { $0 += 1 }
        /// ```
        public func modify(_ body: (inout Value) -> Void) {
            body(&value)
        }

        /// Reads, awaits `body`, then writes. **Other tasks on this actor
        /// may run during `body`.** The write can overwrite their work.
        ///
        /// That is actor reentrancy. Isolation is serial *between* suspension
        /// points, not across them.
        ///
        /// Swift Concurrency: any `await` inside an actor method.
        ///
        /// GCD: a serial queue does not have this unless *you* call `sync`
        /// from inside a block on the same queue (deadlock) or hop out and
        /// back. Actors suspend instead of blocking, so the interleaving is
        /// real and easy to miss.
        ///
        /// ```swift
        /// await counter.readAwaitWrite { current in
        ///     try? await Task.sleep(for: .milliseconds(50))
        ///     return current + 1 // may stomp another increment
        /// }
        /// ```
        ///
        /// - Parameter body: Async transformation of the snapshot.
        /// - Returns: The value written after `body` returns.
        @discardableResult
        public func readAwaitWrite(
            _ body: @Sendable (Value) async -> Value
        ) async -> Value {
            let current = value
            let next = await body(current)
            value = next
            return next
        }
    }
}
