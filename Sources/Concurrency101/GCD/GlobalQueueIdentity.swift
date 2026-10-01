import Dispatch

/// Identifies the system global concurrent queues so teaching asserts can
/// reject barriers on them. Barriers on `DispatchQueue.global()` do not give
/// exclusive access to the process-wide pool.
enum GlobalQueueIdentity {
    static let all: [DispatchQueue] = [
        .global(qos: .userInteractive),
        .global(qos: .userInitiated),
        .global(qos: .default),
        .global(qos: .utility),
        .global(qos: .background),
        .global(qos: .unspecified),
    ]

    static func matches(_ queue: DispatchQueue) -> Bool {
        all.contains { $0 === queue }
    }
}
