import Foundation
import Observation

/// Dual-sink logger: Xcode's console (`print`) and the in-app overlay.
///
/// Call `log` from any queue. `print` happens immediately on that thread so
/// Xcode shows the same line at the same time. The overlay is updated on the
/// main queue.
@MainActor
@Observable
final class DemoLog {
    struct Entry: Identifiable, Equatable {
        let id: UUID
        let uptime: TimeInterval
        let isMainThread: Bool
        let text: String

        var consoleLine: String {
            let lane = isMainThread ? "main    " : "off-main"
            return "\(String(format: "%8.3f", uptime))  \(lane)  \(text)"
        }
    }

    private(set) var entries: [Entry] = []

    private static let overlayCap = 400

    /// Writes one line to Xcode and to the transparent console.
    nonisolated func log(_ text: String) {
        let entry = Entry(
            id: UUID(),
            uptime: ProcessInfo.processInfo.systemUptime,
            isMainThread: Thread.isMainThread,
            text: text
        )
        print(entry.consoleLine)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.entries.append(entry)
                let overflow = self.entries.count - Self.overlayCap
                if overflow > 0 {
                    self.entries.removeFirst(overflow)
                }
            }
        }
    }

    nonisolated func clear() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.entries.removeAll()
            }
        }
        print("— console cleared —")
    }
}
