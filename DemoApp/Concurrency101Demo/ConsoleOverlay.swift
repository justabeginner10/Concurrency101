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
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if log.entries.isEmpty {
                            Text("Run a lesson. Lines print here and in the Xcode console.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(DemoTheme.muted)
                                .padding(.top, 8)
                        }
                        ForEach(Array(log.entries.enumerated()), id: \.element.id) { index, entry in
                            GutteredLine(
                                number: index + 1,
                                gutterWidth: log.entries.count >= 100 ? 28 : 22,
                                attributedText: DemoSyntax.highlight(entry.consoleLine),
                                fontSize: 11,
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

    static let syntaxBrand = phosphor
    static let syntaxLog = Color(red: 0.93, green: 0.50, blue: 0.70)
    static let syntaxKeyword = Color(red: 0.73, green: 0.64, blue: 0.93)
    static let syntaxType = cyan
    static let syntaxCall = Color(red: 0.96, green: 0.84, blue: 0.52)
    static let syntaxString = Color(red: 0.63, green: 0.84, blue: 0.58)
    static let syntaxNumber = Color(red: 0.95, green: 0.68, blue: 0.42)
    static let syntaxPlain = Color.white.opacity(0.86)
}

/// One logical line with a numbered gutter. Soft-wraps hang under the text,
/// so a wrap is not mistaken for a new line.
struct GutteredLine: View {
    let number: Int
    let gutterWidth: CGFloat
    let attributedText: AttributedString
    var fontSize: CGFloat = 12
    var ruleColor: Color = DemoTheme.phosphor

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(number)")
                .font(.system(size: fontSize, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DemoTheme.muted)
                .frame(width: gutterWidth, alignment: .trailing)

            Text(verbatim: "│")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(ruleColor.opacity(0.4))

            Text(attributedText)
                .font(.system(size: fontSize, design: .monospaced))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct NumberedSourceBlock: View {
    let source: String
    var fontSize: CGFloat = 12
    var ruleColor: Color = DemoTheme.phosphor

    var body: some View {
        let rows = Self.rows(from: source)
        let width: CGFloat = rows.count >= 100 ? 28 : 22
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.number) { row in
                GutteredLine(
                    number: row.number,
                    gutterWidth: width,
                    attributedText: DemoSyntax.highlight(row.text),
                    fontSize: fontSize,
                    ruleColor: ruleColor
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func rows(from source: String) -> [(number: Int, text: String)] {
        var parts = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if parts.count > 1, parts.last?.isEmpty == true {
            parts.removeLast()
        }
        if parts.isEmpty {
            parts = [""]
        }
        return parts.enumerated().map { (number: $0.offset + 1, text: $0.element) }
    }
}
