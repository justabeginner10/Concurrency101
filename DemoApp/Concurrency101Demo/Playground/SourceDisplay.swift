import SwiftUI

/// One logical line with a numbered gutter. Soft-wraps hang at the source
/// indent, matching Xcode, so a wrap is not mistaken for a new line.
struct GutteredLine: View {
    let number: Int
    let gutterWidth: CGFloat
    let attributedText: AttributedString
    var fontSize: CGFloat = 12
    var ruleColor: Color = DemoTheme.phosphor

    var body: some View {
        let hang = wrapIndent
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(number)")
                .font(.system(size: fontSize, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DemoTheme.muted)
                .frame(width: gutterWidth, alignment: .trailing)

            Text(verbatim: "│")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(ruleColor.opacity(0.4))

            Text(textAfterIndent)
                .font(.system(size: fontSize, design: .monospaced))
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.leading, hang)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var wrapIndent: CGFloat {
        let columns = DemoSourceType.leadingIndentColumns(String(attributedText.characters))
        guard columns > 0 else { return 0 }
        return CGFloat(columns) * DemoSourceType.monoAdvance(fontSize: fontSize)
    }

    /// Leading whitespace is drawn as padding so wrapped continuations stay
    /// at that indent. The spaces themselves are not in the wrapped `Text`.
    private var textAfterIndent: AttributedString {
        let raw = String(attributedText.characters)
        let whitespace = raw.prefix { $0 == " " || $0 == "\t" }.count
        guard whitespace > 0 else { return attributedText }
        var index = attributedText.startIndex
        for _ in 0..<whitespace {
            index = attributedText.index(afterCharacter: index)
        }
        let trimmed = AttributedString(attributedText[index...])
        return trimmed.characters.isEmpty ? AttributedString(" ") : trimmed
    }
}

struct NumberedSourceBlock: View {
    let source: String
    var fontSize: CGFloat = 12
    var ruleColor: Color = DemoTheme.phosphor

    var body: some View {
        let rows = Self.rows(from: source)
        let width = DemoSourceType.gutterWidth(fontSize: fontSize, lineCount: rows.count)
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
