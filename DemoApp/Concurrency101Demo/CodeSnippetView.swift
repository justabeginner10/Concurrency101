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
    @Binding var showAppleAPI: Bool
    @State private var copied = false

    private var displayed: String {
        showAppleAPI ? appleSnippet : teachingSnippet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(showAppleAPI ? appleLabel : "Concurrency101")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(showAppleAPI ? DemoTheme.cyan : DemoTheme.phosphor.opacity(0.85))

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text("101")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(showAppleAPI ? DemoTheme.muted : DemoTheme.phosphor)
                    Toggle("Show Apple API", isOn: $showAppleAPI)
                        .labelsHidden()
                        .tint(DemoTheme.cyan)
                        .fixedSize()
                    Text(appleLabel == "Apple GCD" ? "GCD" : "Swift")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(showAppleAPI ? DemoTheme.cyan : DemoTheme.muted)
                }

                Button(copied ? "Copied" : "Copy") {
                    copySnippet()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copied = false
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundStyle(DemoTheme.cyan)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(DemoTheme.phosphor.opacity(0.22))

            ScrollView(.vertical, showsIndicators: true) {
                Text(displayed)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 140, maxHeight: 260)
        }
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
