import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// UTF-16 offsets match TextKit, including Unicode and Windows newlines.
/// Soft-wrapped fragments belong to the same logical source line.
enum SandboxLineNumbers {
    static func starts(in source: String) -> [Int] {
        let text = source as NSString
        var starts = [0]
        var offset = 0
        while offset < text.length {
            var end = 0
            text.getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: offset, length: 0))
            guard end > offset else { break }
            offset = end
            if offset < text.length { starts.append(offset) }
        }
        if source.last?.isNewline == true { starts.append(text.length) }
        return starts
    }

    static func rects(starts: [Int], layout: NSLayoutManager, container: NSTextContainer, length: Int) -> [CGRect] {
        layout.ensureLayout(for: container)
        return starts.map { offset in
            if offset >= length { return layout.extraLineFragmentRect }
            let glyph = layout.glyphIndexForCharacter(at: offset)
            return layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
    }
}

#if os(iOS)
final class SandboxTextEditorView: UIView {
    let textView = UITextView(usingTextLayoutManager: false)
    private let gutter = SandboxLineNumberView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gutter.textView = textView
        gutter.isUserInteractionEnabled = false
        gutter.isAccessibilityElement = false
        gutter.backgroundColor = .clear
        addSubview(gutter)
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateGutter(source: String, fontSize: CGFloat) {
        gutter.starts = SandboxLineNumbers.starts(in: source)
        gutter.fontSize = fontSize
        setNeedsLayout()
        redrawGutter()
    }

    func redrawGutter() { gutter.setNeedsDisplay() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let font = UIFont.monospacedSystemFont(ofSize: gutter.fontSize, weight: .regular)
        let digits = (String(gutter.starts.count) as NSString).size(withAttributes: [.font: font]).width
        let width = max(28, ceil(digits) + 16)
        gutter.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        textView.frame = CGRect(x: width, y: 0, width: max(0, bounds.width - width), height: bounds.height)
        redrawGutter()
    }
}

private final class SandboxLineNumberView: UIView {
    weak var textView: UITextView?
    var starts = [0]
    var fontSize: CGFloat = 12

    override func draw(_ rect: CGRect) {
        guard let view = textView else { return }
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(DemoTheme.muted)]
        let lines = SandboxLineNumbers.rects(starts: starts, layout: view.layoutManager,
                                             container: view.textContainer, length: view.textStorage.length)
        UIColor(DemoTheme.phosphor.opacity(0.25)).setFill()
        UIRectFill(CGRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height))
        for (index, line) in lines.enumerated() {
            let y = view.textContainerInset.top + line.minY - view.contentOffset.y
            guard y + font.lineHeight >= 0, y < bounds.height else { continue }
            let number = String(index + 1) as NSString
            let size = number.size(withAttributes: attributes)
            number.draw(at: CGPoint(x: bounds.width - 8 - size.width, y: y), withAttributes: attributes)
        }
    }
}
#elseif os(macOS)
final class SandboxLineNumberRuler: NSRulerView {
    weak var textView: NSTextView?
    private(set) var starts = [0]
    private var fontSize: CGFloat = 12
    override var isFlipped: Bool { true }

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 28
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(source: String, fontSize: CGFloat) {
        starts = SandboxLineNumbers.starts(in: source)
        self.fontSize = fontSize
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let digits = (String(starts.count) as NSString).size(withAttributes: [.font: font]).width
        ruleThickness = max(28, ceil(digits) + 16)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(DemoTheme.void).setFill()
        dirtyRect.fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let view = textView, let layout = view.layoutManager, let container = view.textContainer else { return }
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(DemoTheme.muted)]
        let lines = SandboxLineNumbers.rects(starts: starts, layout: layout, container: container, length: view.string.utf16.count)
        NSColor(DemoTheme.phosphor.opacity(0.25)).setFill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()
        for (index, line) in lines.enumerated() {
            let point = convert(NSPoint(x: 0, y: view.textContainerOrigin.y + line.minY), from: view)
            let number = String(index + 1) as NSString
            let size = number.size(withAttributes: attributes)
            guard point.y + size.height >= 0, point.y < bounds.height else { continue }
            number.draw(at: NSPoint(x: bounds.width - 8 - size.width, y: point.y), withAttributes: attributes)
        }
    }
}
#endif
