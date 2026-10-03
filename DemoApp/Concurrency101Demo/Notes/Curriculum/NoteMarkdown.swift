import Foundation

enum NoteMarkdown {
    static func prepared(_ raw: String, track: LearningTrack) -> String {
        let withoutEmbeds = rewriteObsidianEmbeds(raw)
        return mapOutsideCode(withoutEmbeds) { chunk in
            rewriteWikilinks(rewriteCallouts(chunk), track: track)
        }
    }

    static func noteID(from url: URL) -> String? {
        guard url.scheme == "curriculum" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "id" })?.value
    }

    private static func mapOutsideCode(_ text: String, transform: (String) -> String) -> String {
        let parts = text.components(separatedBy: "```")
        return parts.enumerated().map { index, part in
            index.isMultiple(of: 2) ? transform(part) : part
        }.joined(separator: "```")
    }

    private static func rewriteObsidianEmbeds(_ text: String) -> String {
        let pattern = #"!\[\[([^\]]+)\]\]"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func rewriteCallouts(_ text: String) -> String {
        let pattern = #"(?m)^> \[!([A-Za-z]+)\][^\n]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "> **$1.**")
    }

    private static func rewriteWikilinks(_ text: String, track: LearningTrack) -> String {
        let pattern = #"\[\[([^\]|#]+)(?:#[^\|\]]+)?(?:\|([^\]]+))?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result = text
        for match in matches.reversed() {
            guard let targetRange = Range(match.range(at: 1), in: result) else { continue }
            let target = String(result[targetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let label: String
            if match.numberOfRanges > 2, let labelRange = Range(match.range(at: 2), in: result), !labelRange.isEmpty {
                label = String(result[labelRange])
            } else {
                label = target
            }
            let replacement: String
            if let note = CurriculumCatalog.resolveWikilink(target, in: track),
               let url = noteURL(id: note.id) {
                replacement = "[\(label)](<\(url.absoluteString)>)"
            } else {
                replacement = "**\(label)**"
            }
            if let full = Range(match.range, in: result) {
                result.replaceSubrange(full, with: replacement)
            }
        }
        return result
    }

    private static func noteURL(id: String) -> URL? {
        var components = URLComponents()
        components.scheme = "curriculum"
        components.host = "note"
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        return components.url
    }
}
