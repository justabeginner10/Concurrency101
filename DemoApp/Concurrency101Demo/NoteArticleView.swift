import MarkdownUI
import SwiftUI

struct NoteArticleView: View {
    let markdown: String
    let accent: Color
    let onOpenNote: (URL) -> Void

    var body: some View {
        Markdown(markdown)
            .font(.system(size: DemoLayout.typeSize(16), design: .serif))
            .markdownTheme(.concurrency101(accent: accent, bodySize: DemoLayout.typeSize(16)))
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.88))
                ForegroundColor(DemoTheme.cyan)
                BackgroundColor(Color.white.opacity(0.08))
            }
            .textSelection(.enabled)
            .frame(maxWidth: 760, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "curriculum" {
                    onOpenNote(url)
                    return .handled
                }
                return .systemAction
            })
    }
}

private extension Theme {
    static func concurrency101(accent: Color, bodySize: CGFloat) -> Theme {
        Theme()
            .text {
                ForegroundColor(Color.white.opacity(0.86))
                FontSize(bodySize)
            }
            .strong {
                FontWeight(.semibold)
                ForegroundColor(Color.white.opacity(0.94))
            }
            .emphasis {
                FontStyle(.italic)
            }
            .link {
                ForegroundColor(accent)
            }
            .heading1 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 8, bottom: 14)
                    .markdownTextStyle {
                        FontWeight(.regular)
                        FontSize(.em(1.65))
                        ForegroundColor(accent)
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 26, bottom: 10)
                    .markdownTextStyle {
                        FontWeight(.regular)
                        FontSize(.em(1.28))
                        ForegroundColor(accent)
                    }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.12))
                    .markdownMargin(top: 22, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.08))
                        ForegroundColor(Color.white.opacity(0.92))
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .markdownMargin(top: 18, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        ForegroundColor(Color.white.opacity(0.9))
                    }
            }
            .paragraph { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.28))
                    .markdownMargin(top: 0, bottom: 14)
            }
            .blockquote { configuration in
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 2)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(Color.white.opacity(0.78))
                            FontStyle(.italic)
                        }
                        .relativePadding(.horizontal, length: .em(0.9))
                        .relativePadding(.vertical, length: .em(0.35))
                }
                .background(Color.white.opacity(0.04))
                .markdownMargin(top: 4, bottom: 16)
            }
            .codeBlock { configuration in
                NoteCodeBlock(
                    language: configuration.language,
                    content: configuration.content,
                    label: configuration.label,
                    accent: accent
                )
                .markdownMargin(top: 4, bottom: 16)
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.22))
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: accent.opacity(0.28)))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(Color.clear, Color.white.opacity(0.04))
                    )
                    .markdownMargin(top: 4, bottom: 16)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                            ForegroundColor(accent)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .relativeLineSpacing(.em(0.2))
            }
            .thematicBreak {
                Divider()
                    .overlay(accent.opacity(0.28))
                    .markdownMargin(top: 22, bottom: 22)
            }
    }
}

private struct NoteCodeBlock<Label: View>: View {
    let language: String?
    let content: String
    let label: Label
    let accent: Color

    var body: some View {
        if language?.lowercased() == "mermaid" {
            MermaidFigure(source: content, accent: accent)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let language, !language.isEmpty {
                    Text(verbatim: language)
                        .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                        .foregroundStyle(accent.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    Divider().overlay(accent.opacity(0.22))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.2))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.86))
                            ForegroundColor(Color.white.opacity(0.88))
                        }
                        .padding(12)
                }
            }
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

private struct MermaidFigure: View {
    let source: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagram")
                .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                .foregroundStyle(accent)
            Text(verbatim: source)
                .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: 2)
        }
        .overlay(
            Rectangle()
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.5)
        )
    }
}
