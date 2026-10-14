import Foundation

/// The Playground lesson snippets, read straight from the demo app's
/// scenario libraries so the tests and the app share one copy.
struct LessonSnippet {
    let id: String
    let teaching: String
    let apple: String
}

enum LessonSnippets {
    static let gcd = load("GCDScenarioLibrary.swift")
    static let modern = load("ModernScenarioLibrary.swift")
    static var all: [LessonSnippet] { gcd + modern }

    static func named(_ id: String) -> LessonSnippet {
        guard let s = all.first(where: { $0.id == id }) else {
            fatalError("no lesson snippet with id \(id)")
        }
        return s
    }

    private static func load(_ file: String) -> [LessonSnippet] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("DemoApp/Concurrency101Demo/Playground/Scenarios/\(file)")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("can't read \(url.path)")
        }
        var result: [LessonSnippet] = []
        var currentID: String?
        var teaching: String?
        var collecting: String?
        var buffer: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let name = collecting {
                if trimmed == "\"\"\"," || trimmed == "\"\"\"" {
                    let body = unescape(buffer.map { String($0.dropFirst(min(8, $0.prefix { $0 == " " }.count))) }.joined(separator: "\n"))
                    if name == "teachingSnippet" {
                        teaching = body
                    } else if let id = currentID, let t = teaching {
                        result.append(LessonSnippet(id: id, teaching: t, apple: body))
                        currentID = nil
                        teaching = nil
                    }
                    collecting = nil
                    buffer = []
                } else {
                    buffer.append(line)
                }
                continue
            }
            if trimmed.hasPrefix("id: \""), let start = trimmed.firstIndex(of: "\"") {
                let rest = trimmed[trimmed.index(after: start)...]
                currentID = String(rest.prefix { $0 != "\"" })
            } else if trimmed == "teachingSnippet: \"\"\"" {
                collecting = "teachingSnippet"
            } else if trimmed == "appleSnippet: \"\"\"" {
                collecting = "appleSnippet"
            }
        }
        return result
    }

    /// Undo the Swift string-literal escapes used in the scenario files.
    private static func unescape(_ s: String) -> String {
        var out = ""
        var iterator = s.makeIterator()
        while let c = iterator.next() {
            if c == "\\", let next = iterator.next() {
                switch next {
                case "\\": out.append("\\")
                case "\"": out.append("\"")
                case "n": out.append("\n")
                case "t": out.append("\t")
                default:
                    out.append(c)
                    out.append(next)
                }
            } else {
                out.append(c)
            }
        }
        return out
    }
}
