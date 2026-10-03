import Foundation
import XCTest

enum TestSupport {
    static let timeout: TimeInterval = 2.5
}

/// Thread-safe box for values written from GCD closures in tests.
final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func read() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func write(_ newValue: Value) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func mutate(_ body: (inout Value) -> Void) {
        lock.lock()
        body(&value)
        lock.unlock()
    }
}
