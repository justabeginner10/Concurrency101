import Foundation

/// Tiny helpers for example executables so they can use `updateUI` / main-queue
/// `notify` without deadlocking the main thread on a semaphore.
public enum ExampleSupport {
    /// Boolean that GCD closures can flip from any queue.
    public final class Flag {
        private let lock = NSLock()
        private var value = false

        public init() {}

        public func set() {
            lock.lock()
            value = true
            lock.unlock()
        }

        public func get() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    /// Integer that example tasks can bump from any isolation domain.
    public final class LockedCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Int

        public init(_ value: Int) {
            self.value = value
        }

        public func get() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        public func decrement() {
            lock.lock()
            value -= 1
            lock.unlock()
        }
    }

    /// Thread-safe string log for printing order after async work settles.
    public final class EventLog {
        private let lock = NSLock()
        private var events: [String] = []

        public init() {}

        public func append(_ event: String) {
            lock.lock()
            events.append(event)
            lock.unlock()
            print("  • \(event)")
        }

        public func snapshot() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return events
        }
    }

    /// Whether the current *thread* is the main thread.
    ///
    /// Prefer isolation (`@MainActor`) in real code. Examples print this so
    /// you can see GCD-style main vs off-main next to actor hops.
    public static func currentlyOnMainThread() -> Bool {
        Thread.isMainThread
    }
    ///
    /// Use this instead of `DispatchSemaphore.wait` on the main thread when
    /// the work you are waiting for includes `DispatchQueue.main.async`.
    public static func pumpMainRunLoop(
        until isFinished: @escaping () -> Bool,
        timeout: TimeInterval = 8
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !isFinished(), Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        if !isFinished() {
            fputs("Example timed out waiting for async GCD work.\n", stderr)
        }
    }
}
