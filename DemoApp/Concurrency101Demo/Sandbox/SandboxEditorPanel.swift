import SwiftUI
import Concurrency101Sim
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// The editable code, with live compile errors underneath.
struct SandboxEditorPanel: View {
    @Bindable var session: SandboxSession
    let accent: Color
    @AppStorage(DemoSourceType.storageKey) private var sourceFontSize = DemoSourceType.defaultSize
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Code")
                    .font(.system(size: DemoLayout.typeSize(12), design: .serif))
                    .foregroundStyle(accent.opacity(0.85))
                Text(verbatim: status)
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .foregroundStyle(session.errorCount > 0 ? DemoTheme.freeze : DemoTheme.muted)
                Spacer(minLength: 8)
                Button(copied ? "Copied" : "Copy") {
                    copy()
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

            Divider().overlay(accent.opacity(0.22))

            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !session.diagnostics.isEmpty {
                Divider().overlay(DemoTheme.freeze.opacity(0.4))
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(session.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            Text(verbatim: "line \(diagnostic.line): \(diagnostic.message)")
                                .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                                .foregroundStyle(diagnostic.severity == .error ? DemoTheme.freeze : DemoTheme.syntaxCall)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 96)
            }
        }
        .background(Color.white.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var status: String {
        switch session.errorCount {
        case 0: return "no errors"
        case 1: return "1 error"
        default: return "\(session.errorCount) errors"
        }
    }

    @ViewBuilder
    private var editor: some View {
        let field = TextEditor(text: $session.source)
            .font(.system(size: CGFloat(sourceFontSize), design: .monospaced))
            .foregroundStyle(DemoTheme.syntaxPlain)
            .scrollContentBackground(.hidden)
            .autocorrectionDisabled()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .accessibilityLabel("Code editor")
        #if os(iOS)
        field
            .textInputAutocapitalization(.never)
            .keyboardType(.asciiCapable)
        #else
        field
        #endif
    }

    private func copy() {
        #if os(iOS)
        UIPasteboard.general.string = session.source
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.source, forType: .string)
        #endif
    }
}
