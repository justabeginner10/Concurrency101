import SwiftUI

struct ConsoleOverlay: View {
    enum Chrome {
        case docked
        case pane
    }

    @ObservedObject var log: DemoLog
    @Binding var expanded: Bool
    var chrome: Chrome = .docked
    @AppStorage(DemoSourceType.storageKey) private var sourceFontSize = DemoSourceType.defaultSize

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("trace")
                    .font(.system(size: DemoLayout.typeSize(12), design: .serif))
                    .foregroundStyle(DemoTheme.phosphor.opacity(0.85))
                Text("same lines as Xcode")
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)
                Spacer()
                if chrome == .docked {
                    Button(expanded ? "Fold" : "Expand") {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    }
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .buttonStyle(.plain)
                    .foregroundStyle(DemoTheme.cyan)
                }
                Button("Clear") { log.clear() }
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .buttonStyle(.plain)
                    .foregroundStyle(DemoTheme.phosphor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().overlay(DemoTheme.phosphor.opacity(0.25))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if log.entries.isEmpty {
                            Text("Run a lesson. Lines print here and in the Xcode console.")
                                .font(.system(size: CGFloat(sourceFontSize), design: .monospaced))
                                .foregroundStyle(DemoTheme.muted)
                                .padding(.top, 8)
                        }
                        ForEach(Array(log.entries.enumerated()), id: \.element.id) { index, entry in
                            GutteredLine(
                                number: index + 1,
                                gutterWidth: DemoSourceType.gutterWidth(
                                    fontSize: CGFloat(sourceFontSize),
                                    lineCount: log.entries.count
                                ),
                                attributedText: DemoSyntax.highlight(entry.consoleLine),
                                fontSize: CGFloat(sourceFontSize),
                                ruleColor: entry.isMainThread ? DemoTheme.phosphor : DemoTheme.cyan
                            )
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
        .frame(height: chrome == .docked ? (expanded ? 340 : 168) : nil)
        .frame(maxHeight: chrome == .pane ? .infinity : nil)
        .background(.ultraThinMaterial, in: Rectangle())
        .overlay(
            Rectangle()
                .strokeBorder(DemoTheme.phosphor.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(chrome == .docked ? 0.35 : 0), radius: chrome == .docked ? 18 : 0, y: chrome == .docked ? -4 : 0)
    }
}
