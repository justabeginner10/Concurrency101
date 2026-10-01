import Foundation

/// Dual-sink logger: Xcode's console (`print`) and the in-app overlay.
///
/// Call `log` from any queue. `print` happens immediately on that thread so
/// Xcode shows the same line at the same time. The overlay is updated on the
/// main queue.
final class DemoLog: ObservableObject {
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

    @Published private(set) var entries: [Entry] = []

    private let lock = NSLock()

    /// Writes one line to Xcode and to the transparent console.
    func log(_ text: String) {
        let entry = Entry(
            id: UUID(),
            uptime: ProcessInfo.processInfo.systemUptime,
            isMainThread: Thread.isMainThread,
            text: text
        )
        print(entry.consoleLine)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > 400 {
                self.entries.removeFirst(self.entries.count - 400)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
        print("— console cleared —")
    }
}
