import SwiftUI

/// Lightweight highlighting for playground snippets and the glass console.
/// Not a Swift parser — paints the tokens a learner should spot at a glance.
enum DemoSyntax {
    static func highlight(_ text: String, defaultColor: Color = DemoTheme.syntaxPlain) -> AttributedString {
        if text.isEmpty {
            return AttributedString(" ")
        }
        var result = AttributedString()
        var index = text.startIndex
        while index < text.endIndex {
            let (end, color) = token(from: index, in: text, defaultColor: defaultColor)
            var piece = AttributedString(String(text[index..<end]))
            piece.foregroundColor = color
            result += piece
            index = end
        }
        return result
    }

    private static func token(
        from start: String.Index,
        in text: String,
        defaultColor: Color
    ) -> (String.Index, Color) {
        let ch = text[start]

        if text[start...].hasPrefix("off-main") {
            return (text.index(start, offsetBy: 8), DemoTheme.cyan)
        }

        if ch == "\"" {
            return (scanString(from: start, in: text), DemoTheme.syntaxString)
        }

        if ch == "/", text.index(after: start) < text.endIndex, text[text.index(after: start)] == "/" {
            return (text.endIndex, DemoTheme.muted)
        }

        if ch == "." {
            let afterDot = text.index(after: start)
            if afterDot < text.endIndex, isIdentStart(text[afterDot]) {
                let end = scanIdent(from: afterDot, in: text)
                let name = String(text[afterDot..<end])
                return (end, color(for: name, defaultColor: defaultColor))
            }
        }

        if isIdentStart(ch) {
            let end = scanIdent(from: start, in: text)
            let name = String(text[start..<end])
            return (end, color(for: name, defaultColor: defaultColor))
        }

        if ch.isNumber {
            return (scanNumber(from: start, in: text), DemoTheme.syntaxNumber)
        }

        return (text.index(after: start), defaultColor)
    }

    private static func color(for name: String, defaultColor: Color) -> Color {
        if logNames.contains(name) { return DemoTheme.syntaxLog }
        if brandNames.contains(name) { return DemoTheme.syntaxBrand }
        if name == "main" { return DemoTheme.phosphor }
        if keywords.contains(name) { return DemoTheme.syntaxKeyword }
        if types.contains(name) { return DemoTheme.syntaxType }
        if calls.contains(name) { return DemoTheme.syntaxCall }
        return defaultColor
    }

    private static func isIdentStart(_ ch: Character) -> Bool {
        ch.isLetter || ch == "_"
    }

    private static func isIdentBody(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_"
    }

    private static func scanIdent(from start: String.Index, in text: String) -> String.Index {
        var index = text.index(after: start)
        while index < text.endIndex, isIdentBody(text[index]) {
            index = text.index(after: index)
        }
        return index
    }

    private static func scanNumber(from start: String.Index, in text: String) -> String.Index {
        var index = text.index(after: start)
        var seenDot = false
        while index < text.endIndex {
            let ch = text[index]
            if ch.isNumber {
                index = text.index(after: index)
            } else if ch == ".", !seenDot {
                let next = text.index(after: index)
                guard next < text.endIndex, text[next].isNumber else { break }
                seenDot = true
                index = next
            } else {
                break
            }
        }
        return index
    }

    private static func scanString(from start: String.Index, in text: String) -> String.Index {
        var index = text.index(after: start)
        while index < text.endIndex {
            let ch = text[index]
            if ch == "\\" {
                index = text.index(after: index)
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                continue
            }
            if ch == "\"" {
                return text.index(after: index)
            }
            index = text.index(after: index)
        }
        return text.endIndex
    }

    private static let logNames: Set<String> = ["log"]

    private static let brandNames: Set<String> = [
        "Concurrency101", "GCD", "Modern",
    ]

    private static let keywords: Set<String> = [
        "let", "var", "func", "in", "if", "else", "for", "while", "return",
        "try", "catch", "throw", "throws", "rethrows", "await", "async",
        "guard", "switch", "case", "default", "break", "continue", "defer",
        "true", "false", "nil", "self", "Self", "as", "is", "where",
        "struct", "class", "enum", "actor", "protocol", "extension",
        "static", "public", "private", "internal", "some", "any",
        "isolated", "nonisolated", "do", "repeat", "import",
        "override", "mutating",
    ]

    private static let types: Set<String> = [
        "DispatchQueue", "DispatchGroup", "DispatchWorkItem", "DispatchTime",
        "DispatchQoS", "Thread", "MainActor", "Task", "TaskGroup",
        "ExclusiveState", "CompletionCounter", "CancellationError",
        "TaskPriority", "Duration", "Blocking", "UUID", "Void",
        "DemoLog",
    ]

    private static let calls: Set<String> = [
        "runWhenUserIsNotWaiting", "runUserRequestedWork", "runForImmediateUI",
        "runMaintenanceWork", "runSeveralThenContinue", "runDetachedFromCaller",
        "runExclusiveWrite", "makePrivateSerialLane", "makeSharedConcurrentLane",
        "makeCancellableWork", "blockThisThreadUntilFinished",
        "blockThisThreadUntilAllJobsEnd", "parkThisThreadUntilTaskFinishes",
        "pauseThisTask", "waitForThrowingCallback", "waitForCallback",
        "waitForUI", "updateUI", "runOnLane", "runTwoAtOnce", "letOthersRun",
        "throwIfCancelled", "isCurrentTaskCancelled", "readAwaitWrite",
        "snapshot", "replace", "modify", "beginOne", "endOne", "whenAllHaveEnded",
        "asyncAfter", "global", "notify", "enter", "leave", "wait",
        "detached", "checkCancellation", "isCancelled", "sleep",
        "withTaskGroup", "withCheckedContinuation", "withCheckedThrowingContinuation",
        "yield", "cancel", "run", "qos", "userInitiated", "userInteractive",
        "utility", "background", "high", "barrier", "label", "deadline",
        "now", "seconds", "forTimeInterval",
    ]
}
