import SwiftUI

struct ConsoleOverlay: View {
    @ObservedObject var log: DemoLog
    @Binding var expanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("trace")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(DemoTheme.phosphor.opacity(0.85))
                Text("same lines as Xcode")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)
                Spacer()
                Button(expanded ? "Fold" : "Expand") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.system(size: 11, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundStyle(DemoTheme.cyan)
                Button("Clear") { log.clear() }
                    .font(.system(size: 11, design: .monospaced))
                    .buttonStyle(.plain)
                    .foregroundStyle(DemoTheme.phosphor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().overlay(DemoTheme.phosphor.opacity(0.25))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if log.entries.isEmpty {
                            Text("Run a lesson. Lines print here and in the Xcode console.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(DemoTheme.muted)
                                .padding(.top, 8)
                        }
                        ForEach(log.entries) { entry in
                            Text(entry.consoleLine)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(entry.isMainThread ? DemoTheme.phosphor : DemoTheme.cyan)
                                .textSelection(.enabled)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .onChange(of: log.entries.count) { _, _ in
                    if let last = log.entries.last {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: expanded ? 340 : 168)
        .background(.ultraThinMaterial, in: Rectangle())
        .overlay(
            Rectangle()
                .strokeBorder(DemoTheme.phosphor.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, y: -4)
    }
}

enum DemoTheme {
    static let void = Color(red: 0.09, green: 0.08, blue: 0.12)
    static let phosphor = Color(red: 0.91, green: 0.72, blue: 0.43)
    static let cyan = Color(red: 0.49, green: 0.72, blue: 0.79)
    static let freeze = Color(red: 0.77, green: 0.36, blue: 0.36)
    static let muted = Color.white.opacity(0.45)
}
