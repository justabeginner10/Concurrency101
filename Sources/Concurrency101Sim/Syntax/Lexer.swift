/// A line and column in the learner's source, both starting at 1.
public struct SourceLocation: Hashable, Sendable, Comparable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        (lhs.line, lhs.column) < (rhs.line, rhs.column)
    }
}

/// One piece of a string literal: plain text, or the source inside `\( … )`.
enum StringPart: Equatable {
    case text(String)
    case interpolation(String, SourceLocation)
}

enum TokenKind: Equatable {
    case identifier(String)
    case keyword(String)
    case int(Int)
    case double(Double)
    case string([StringPart])
    case punct(String)
    case attribute(String)
    case dollar(Int)
    case eof
}

struct Token: Equatable {
    var kind: TokenKind
    var loc: SourceLocation
    /// A line break sits between this token and the one before it.
    var newlineBefore: Bool
    /// Whitespace (or a line break) sits between this token and the one before it.
    var spaceBefore: Bool
}

struct SyntaxError: Error {
    var loc: SourceLocation
    var message: String
}

/// Turns source text into tokens. Accepts the punctuation an iOS keyboard
/// substitutes (curly quotes, the single-character ellipsis) so a learner
/// typing on a phone is not fighting smart punctuation.
struct Lexer {
    static let keywords: Set<String> = [
        "let", "var", "func", "class", "struct", "enum", "for", "in", "while", "repeat",
        "if", "else", "guard", "return", "break", "continue", "do", "catch", "try", "await",
        "throws", "rethrows", "throw", "defer", "is", "as", "true", "false", "nil", "self",
        "Self", "init", "switch", "case", "default", "inout", "static", "where",
    ]

    private static let puncts: [String] = [
        "..<", "...", "->", "==", "!=", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=", "%=",
        "??", "?.",
        "{", "}", "(", ")", "[", "]", ",", ".", ":", ";", "=", "+", "-", "*", "/", "%", "<",
        ">", "!", "?", "&",
    ]

    private let chars: [Character]
    private var index = 0
    private var line = 1
    private var column = 1
    private let lineOffset: Int
    private let columnOffset: Int

    init(_ source: String, startingAt start: SourceLocation = SourceLocation(line: 1, column: 1)) {
        chars = Array(Self.normalize(source))
        lineOffset = start.line - 1
        columnOffset = start.column - 1
    }

    /// Smart punctuation from iOS keyboards, mapped back to ASCII.
    static func normalize(_ source: String) -> String {
        var out = ""
        out.reserveCapacity(source.count)
        for ch in source {
            switch ch {
            case "\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}": out.append("\"")
            case "\u{2018}", "\u{2019}": out.append("'")
            case "\u{2026}": out.append("...")
            case "\u{00A0}": out.append(" ")
            case "\r\n", "\r": out.append("\n")
            default: out.append(ch)
            }
        }
        return out
    }

    private var location: SourceLocation {
        SourceLocation(
            line: line + lineOffset,
            column: line == 1 ? column + columnOffset : column
        )
    }

    private func peek(_ offset: Int = 0) -> Character? {
        let i = index + offset
        return i < chars.count ? chars[i] : nil
    }

    private mutating func advance() -> Character {
        let ch = chars[index]
        index += 1
        if ch == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var newline = false
        var space = false
        while true {
            let skipped = try skipTrivia()
            newline = newline || skipped.newline
            space = space || skipped.space || skipped.newline
            guard let ch = peek() else {
                tokens.append(Token(kind: .eof, loc: location, newlineBefore: true, spaceBefore: true))
                return tokens
            }
            let start = location
            let kind = try lexToken(startingWith: ch)
            tokens.append(Token(kind: kind, loc: start, newlineBefore: newline, spaceBefore: space))
            newline = false
            space = false
        }
    }

    private mutating func skipTrivia() throws -> (newline: Bool, space: Bool) {
        var sawNewline = false
        var sawSpace = false
        while let ch = peek() {
            if ch == "\n" {
                sawNewline = true
                _ = advance()
            } else if ch == " " || ch == "\t" {
                sawSpace = true
                _ = advance()
            } else if ch == "/", peek(1) == "/" {
                while let c = peek(), c != "\n" { _ = advance() }
            } else if ch == "/", peek(1) == "*" {
                let start = location
                _ = advance(); _ = advance()
                var depth = 1
                while depth > 0 {
                    guard let c = peek() else {
                        throw SyntaxError(loc: start, message: "unterminated /* comment")
                    }
                    if c == "/", peek(1) == "*" {
                        depth += 1; _ = advance(); _ = advance()
                    } else if c == "*", peek(1) == "/" {
                        depth -= 1; _ = advance(); _ = advance()
                    } else {
                        if c == "\n" { sawNewline = true }
                        _ = advance()
                    }
                }
                sawSpace = true
            } else {
                break
            }
        }
        return (sawNewline, sawSpace)
    }

    private mutating func lexToken(startingWith ch: Character) throws -> TokenKind {
        if ch == "\"" {
            return .string(try lexString())
        }
        if ch.isNumber {
            return try lexNumber()
        }
        if ch == "$", let next = peek(1), next.isNumber {
            _ = advance()
            var digits = ""
            while let c = peek(), c.isNumber { digits.append(advance()) }
            return .dollar(Int(digits) ?? 0)
        }
        if ch == "@" {
            _ = advance()
            let name = lexIdentifierText()
            if name.isEmpty {
                throw SyntaxError(loc: location, message: "expected an attribute name after '@'")
            }
            return .attribute(name)
        }
        if ch == "#" {
            _ = advance()
            return .identifier("#" + lexIdentifierText())
        }
        if ch == "`" {
            _ = advance()
            let name = lexIdentifierText()
            if peek() == "`" { _ = advance() }
            return .identifier(name)
        }
        if Self.isIdentifierStart(ch) {
            let name = lexIdentifierText()
            return Self.keywords.contains(name) ? .keyword(name) : .identifier(name)
        }
        for p in Self.puncts where matches(p) {
            for _ in p { _ = advance() }
            return .punct(p)
        }
        throw SyntaxError(loc: location, message: "unexpected character '\(ch)'")
    }

    private func matches(_ text: String) -> Bool {
        var i = 0
        for c in text {
            guard peek(i) == c else { return false }
            i += 1
        }
        return true
    }

    static func isIdentifierStart(_ ch: Character) -> Bool {
        ch == "_" || ch.isLetter
    }

    private mutating func lexIdentifierText() -> String {
        var name = ""
        while let c = peek(), Self.isIdentifierStart(c) || c.isNumber {
            name.append(advance())
        }
        return name
    }

    private mutating func lexNumber() throws -> TokenKind {
        let start = location
        var text = ""
        var isDouble = false
        while let c = peek(), c.isNumber || c == "_" {
            let d = advance()
            if d != "_" { text.append(d) }
        }
        if peek() == ".", let next = peek(1), next.isNumber {
            isDouble = true
            text.append(advance())
            while let c = peek(), c.isNumber || c == "_" {
                let d = advance()
                if d != "_" { text.append(d) }
            }
        }
        if let e = peek(), e == "e" || e == "E" {
            let sign = peek(1)
            if let s = sign, s.isNumber || ((s == "-" || s == "+") && (peek(2)?.isNumber ?? false)) {
                isDouble = true
                text.append(advance())
                if peek() == "-" || peek() == "+" { text.append(advance()) }
                while let c = peek(), c.isNumber { text.append(advance()) }
            }
        }
        if isDouble {
            guard let value = Double(text) else {
                throw SyntaxError(loc: start, message: "invalid number '\(text)'")
            }
            return .double(value)
        }
        guard let value = Int(text) else {
            throw SyntaxError(loc: start, message: "number '\(text)' is too large")
        }
        return .int(value)
    }

    private mutating func lexString() throws -> [StringPart] {
        let start = location
        _ = advance()
        if peek() == "\"", peek(1) == "\"" {
            throw SyntaxError(loc: start, message: "multi-line \"\"\" strings aren't supported in the sandbox yet")
        }
        var parts: [StringPart] = []
        var text = ""
        while true {
            guard let ch = peek(), ch != "\n" else {
                throw SyntaxError(loc: start, message: "unterminated string literal")
            }
            if ch == "\"" {
                _ = advance()
                break
            }
            if ch == "\\" {
                _ = advance()
                guard let esc = peek() else {
                    throw SyntaxError(loc: start, message: "unterminated string literal")
                }
                if esc == "(" {
                    _ = advance()
                    if !text.isEmpty {
                        parts.append(.text(text))
                        text = ""
                    }
                    let exprStart = location
                    let inner = try scanInterpolation(from: start)
                    parts.append(.interpolation(inner, exprStart))
                    continue
                }
                _ = advance()
                switch esc {
                case "n": text.append("\n")
                case "t": text.append("\t")
                case "0": text.append("\0")
                case "\"": text.append("\"")
                case "'": text.append("'")
                case "\\": text.append("\\")
                default:
                    throw SyntaxError(loc: location, message: "unknown escape '\\\(esc)' in string")
                }
                continue
            }
            text.append(advance())
        }
        if !text.isEmpty || parts.isEmpty {
            parts.append(.text(text))
        }
        return parts
    }

    /// Reads the source between `\(` and its matching `)`, allowing nested
    /// parentheses and string literals inside.
    private mutating func scanInterpolation(from start: SourceLocation) throws -> String {
        var depth = 1
        var inner = ""
        var inString = false
        while true {
            guard let c = peek(), c != "\n" else {
                throw SyntaxError(loc: start, message: "unterminated \\( in string")
            }
            _ = advance()
            if inString {
                inner.append(c)
                if c == "\\", let n = peek() {
                    inner.append(advance())
                    _ = n
                } else if c == "\"" {
                    inString = false
                }
                continue
            }
            if c == "\"" {
                inString = true
            } else if c == "(" {
                depth += 1
            } else if c == ")" {
                depth -= 1
                if depth == 0 { return inner }
            }
            inner.append(c)
        }
    }
}
