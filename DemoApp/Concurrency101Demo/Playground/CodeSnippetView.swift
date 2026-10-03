import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CodeSnippetView: View {
    let teachingSnippet: String
    let appleSnippet: String
    let appleLabel: String
    var appleChip: String = "Swift"
    @Binding var showAppleAPI: Bool
    var fillsAvailableHeight: Bool = false
    @AppStorage(DemoSourceType.storageKey) private var sourceFontSize = DemoSourceType.defaultSize
    @State private var copied = false

    private var displayed: String {
        showAppleAPI ? appleSnippet : teachingSnippet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(showAppleAPI ? appleLabel : "Concurrency101")
                    .font(.system(size: DemoLayout.typeSize(12), design: .serif))
                    .foregroundStyle(showAppleAPI ? DemoTheme.cyan : DemoTheme.phosphor.opacity(0.85))

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text("101")
                        .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                        .foregroundStyle(showAppleAPI ? DemoTheme.muted : DemoTheme.phosphor)
                    Toggle("Show Apple API", isOn: $showAppleAPI)
                        .labelsHidden()
                        .tint(DemoTheme.cyan)
                        .fixedSize()
                    Text(verbatim: appleChip)
                        .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                        .foregroundStyle(showAppleAPI ? DemoTheme.cyan : DemoTheme.muted)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(DemoTheme.phosphor.opacity(0.22))

            ScrollView(.vertical, showsIndicators: true) {
                NumberedSourceBlock(
                    source: displayed,
                    fontSize: CGFloat(sourceFontSize),
                    ruleColor: showAppleAPI ? DemoTheme.cyan : DemoTheme.phosphor
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
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(DemoTheme.phosphor.opacity(0.22), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
