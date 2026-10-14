import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// An editable source buffer, styled with Playground's syntax palette.
/// Recolor attributes in place so typing keeps the native selection and undo.
#if os(iOS)
struct SandboxCodeEditor: UIViewRepresentable {
    @Binding var source: String
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(source: $source, fontSize: fontSize) }

    func makeUIView(context: Context) -> SandboxTextEditorView {
        let editor = SandboxTextEditorView(frame: .zero)
        let view = editor.textView
        view.backgroundColor = .clear
        view.tintColor = UIColor(DemoTheme.cyan)
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.spellCheckingType = .no
        view.keyboardType = .asciiCapable
        view.accessibilityLabel = "Code editor"
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.delegate = context.coordinator
        context.coordinator.editor = editor
        return editor
    }

    func updateUIView(_ editor: SandboxTextEditorView, context: Context) {
        let view = editor.textView
        context.coordinator.source = $source
        context.coordinator.fontSize = fontSize
        guard view.markedTextRange == nil else { return }
        if view.text != source {
            view.text = source
        }
        context.coordinator.highlight(view)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var source: Binding<String>
        var fontSize: CGFloat
        weak var editor: SandboxTextEditorView?
        private var styledSource: String?
        private var styledFontSize: CGFloat?
        private var isStyling = false

        init(source: Binding<String>, fontSize: CGFloat) {
            self.source = source
            self.fontSize = fontSize
        }

        func textViewDidChange(_ view: UITextView) {
            guard !isStyling else { return }
            source.wrappedValue = view.text
            guard view.markedTextRange == nil else { return }
            highlight(view)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            editor?.redrawGutter()
        }

        func highlight(_ view: UITextView) {
            let text = view.text ?? ""
            guard styledSource != text || styledFontSize != fontSize else { return }
            isStyling = true
            defer { isStyling = false }
            let selection = view.selectedRange
            SandboxCodeStyle.apply(to: view.textStorage, source: text, fontSize: fontSize, undoManager: view.undoManager)
            view.selectedRange = selection
            view.typingAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor(DemoTheme.syntaxPlain),
            ]
            styledSource = text
            styledFontSize = fontSize
            editor?.updateGutter(source: text, fontSize: fontSize)
        }
    }
}
#elseif os(macOS)
struct SandboxCodeEditor: NSViewRepresentable {
    @Binding var source: String
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(source: $source, fontSize: fontSize) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let view = NSTextView(frame: .zero)
        view.drawsBackground = false
        view.isRichText = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isGrammarCheckingEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        view.textContainerInset = NSSize(width: 0, height: 8)
        view.insertionPointColor = NSColor(DemoTheme.cyan)
        view.setAccessibilityLabel("Code editor")
        view.delegate = context.coordinator
        view.textStorage?.delegate = context.coordinator
        context.coordinator.textView = view
        scroll.documentView = view
        let ruler = SandboxLineNumberRuler(scrollView: scroll, textView: view)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.ruler = ruler
        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main
        ) { [weak ruler] _ in ruler?.needsDisplay = true }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        context.coordinator.source = $source
        context.coordinator.fontSize = fontSize
        guard !view.hasMarkedText() else { return }
        if view.string != source {
            view.string = source
        }
        context.coordinator.highlight(view)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var source: Binding<String>
        var fontSize: CGFloat
        weak var textView: NSTextView?
        weak var ruler: SandboxLineNumberRuler?
        var scrollObserver: NSObjectProtocol?
        private var styledSource: String?
        private var styledFontSize: CGFloat?
        private var isStyling = false

        init(source: Binding<String>, fontSize: CGFloat) {
            self.source = source
            self.fontSize = fontSize
        }

        deinit {
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
        }

        func textDidChange(_ notification: Notification) {
            guard !isStyling, let view = notification.object as? NSTextView else { return }
            source.wrappedValue = view.string
            guard !view.hasMarkedText() else { return }
            highlight(view)
        }

        func textStorage(_ storage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                         range editedRange: NSRange, changeInLength delta: Int) {
            guard !isStyling, editedMask.contains(.editedCharacters), source.wrappedValue != storage.string else { return }
            // Undo can change storage without going through textDidChange.
            source.wrappedValue = storage.string
            // Style after the character edit has finished processing.
            Task { @MainActor [weak self] in
                guard let self, let view = self.textView, !view.hasMarkedText() else { return }
                self.highlight(view)
            }
        }

        func highlight(_ view: NSTextView) {
            guard let storage = view.textStorage,
                  styledSource != view.string || styledFontSize != fontSize else { return }
            isStyling = true
            defer { isStyling = false }
            let selection = view.selectedRanges
            SandboxCodeStyle.apply(to: storage, source: view.string, fontSize: fontSize, undoManager: view.undoManager)
            view.selectedRanges = selection
            view.typingAttributes = [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor(DemoTheme.syntaxPlain),
            ]
            styledSource = view.string
            styledFontSize = fontSize
            ruler?.update(source: view.string, fontSize: fontSize)
        }
    }
}
#endif

private enum SandboxCodeStyle {
    static func apply(to storage: NSTextStorage, source: String, fontSize: CGFloat, undoManager: UndoManager?) {
        let highlighted = DemoSyntax.editableSource(source, fontSize: fontSize)
        // Syntax colors are presentation, not an edit the learner should undo.
        let wasUndoEnabled = undoManager?.isUndoRegistrationEnabled == true
        if wasUndoEnabled { undoManager?.disableUndoRegistration() }
        defer { if wasUndoEnabled { undoManager?.enableUndoRegistration() } }
        storage.beginEditing()
        highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length)) { attributes, range, _ in
            storage.setAttributes(attributes, range: range)
        }
        storage.endEditing()
    }
}
