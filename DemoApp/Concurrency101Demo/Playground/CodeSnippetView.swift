import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CodeSnippetView: View {
    private enum Presentation {
        case comparison
        case source
    }

    let teachingSnippet: String
    let appleSnippet: String
    let appleLabel: String
    var appleChip: String = "Swift"
    @Binding var showAppleAPI: Bool
    var fillsAvailableHeight: Bool = false
    var isMaximized: Bool = false
    var onToggleMaximize: (() -> Void)? = nil
    private let presentation: Presentation
    @AppStorage(DemoSourceType.storageKey) private var sourceFontSize = DemoSourceType.defaultSize
    @State private var copied = false

    init(
        teachingSnippet: String,
        appleSnippet: String,
        appleLabel: String,
        appleChip: String = "Swift",
        showAppleAPI: Binding<Bool>,
        fillsAvailableHeight: Bool = false,
        isMaximized: Bool = false,
        onToggleMaximize: (() -> Void)? = nil
    ) {
        self.teachingSnippet = teachingSnippet
        self.appleSnippet = appleSnippet
        self.appleLabel = appleLabel
        self.appleChip = appleChip
        self._showAppleAPI = showAppleAPI
        self.fillsAvailableHeight = fillsAvailableHeight
        self.isMaximized = isMaximized
        self.onToggleMaximize = onToggleMaximize
        self.presentation = .comparison
    }

    /// One snippet in the same chrome as the playground, without the Apple comparison toggle.
    init(source: String) {
        self.teachingSnippet = source
        self.appleSnippet = ""
        self.appleLabel = ""
        self.appleChip = "Swift"
        self._showAppleAPI = .constant(false)
        self.fillsAvailableHeight = false
        self.isMaximized = false
        self.onToggleMaximize = nil
        self.presentation = .source
    }

    private var displayed: String {
        switch presentation {
        case .source:
            teachingSnippet
        case .comparison:
            showAppleAPI ? appleSnippet : teachingSnippet
        }
    }

    private var ruleColor: Color {
        switch presentation {
        case .source:
            DemoTheme.phosphor
        case .comparison:
            showAppleAPI ? DemoTheme.cyan : DemoTheme.phosphor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(headerTitle)
                    .font(.system(size: DemoLayout.typeSize(12), design: .serif))
                    .foregroundStyle(headerColor)

                Spacer(minLength: 8)

                if presentation == .comparison {
                    HStack(spacing: 6) {
                        Text("101")
                            .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                            .foregroundStyle(showAppleAPI ? DemoTheme.muted : DemoTheme.phosphor)
                        Toggle("Show Apple API", isOn: $showAppleAPI)
                            .labelsHidden()
                            .tint(DemoTheme.cyan)
                            .fixedSize()
                        Text(verbatim: appleChip)
                            .font(.system(size: DemoLayout.typeSize(9), design: .monospaced))
                            .foregroundStyle(showAppleAPI ? DemoTheme.cyan : DemoTheme.muted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }

                Button(copied ? "Copied" : "Copy") {
                    copySnippet()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copied = false
                    }
                }
                .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                .buttonStyle(.plain)
                .foregroundStyle(DemoTheme.cyan)

                if let onToggleMaximize {
                    PanelSizeButton(isMaximized: isMaximized, action: onToggleMaximize)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(DemoTheme.phosphor.opacity(0.22))

            ScrollView(.vertical) {
                NumberedSourceBlock(
                    source: displayed,
                    fontSize: CGFloat(sourceFontSize),
                    ruleColor: ruleColor
                )
                .padding(12)
            }
            .frame(
                minHeight: fillsAvailableHeight ? 0 : 140,
                maxHeight: fillsAvailableHeight ? .infinity : 260
            )
        }
        .frame(maxHeight: fillsAvailableHeight ? .infinity : nil)
        .background(Color.white.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(DemoTheme.phosphor.opacity(0.22), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var headerTitle: String {
        switch presentation {
        case .source:
            "Snippet"
        case .comparison:
            showAppleAPI ? appleLabel : "Concurrency101"
        }
    }

    private var headerColor: Color {
        switch presentation {
        case .source:
            DemoTheme.phosphor.opacity(0.85)
        case .comparison:
            showAppleAPI ? DemoTheme.cyan : DemoTheme.phosphor.opacity(0.85)
        }
    }

    private func copySnippet() {
        #if os(iOS)
        UIPasteboard.general.string = displayed
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayed, forType: .string)
        #endif
    }
}
