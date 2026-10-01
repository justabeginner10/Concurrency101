import Foundation

struct CurriculumNote: Identifiable, Hashable {
    let id: String
    let indexLabel: String
    let title: String
    let fileName: String
    let subdirectory: String
}

struct CurriculumSection: Identifiable, Hashable {
    let id: String
    let title: String
    let notes: [CurriculumNote]
}

enum CurriculumCatalog {
    static func sections(for track: LearningTrack) -> [CurriculumSection] {
        switch track {
        case .gcd: return gcd
        case .modern: return modern
        }
    }

    static func notes(for track: LearningTrack) -> [CurriculumNote] {
        sections(for: track).flatMap(\.notes)
    }

    static func note(id: String, in track: LearningTrack) -> CurriculumNote? {
        notes(for: track).first { $0.id == id }
    }

    static func resolveWikilink(_ raw: String, in track: LearningTrack) -> CurriculumNote? {
        let needle = normalize(raw)
        let all = notes(for: track)
        if let exact = all.first(where: {
            normalize($0.id) == needle
                || normalize($0.title) == needle
                || normalize($0.fileName) == needle
        }) {
            return exact
        }
        let matches = all.filter { note in
            normalize(note.fileName).contains(needle)
                || needle.contains(normalize(note.fileName))
                || normalize(note.title) == needle
        }
        if matches.count == 1 { return matches[0] }
        return all.first {
            normalize($0.fileName).hasSuffix(needle) || needle.hasSuffix(normalize($0.title))
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: ".md", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static let gcd: [CurriculumSection] = [
        CurriculumSection(
            id: "path",
            title: "Path",
            notes: [
                gcdNote("gcd-00", file: "00 - Grand Central Dispatch (GCD) Index", index: "00", title: "Index"),
                gcdNote("gcd-01", file: "01 - GCD Mental Model and Architecture", index: "01", title: "Mental Model and Architecture"),
                gcdNote("gcd-02", file: "02 - Dispatch Queues - Serial, Concurrent, Main, and Global", index: "02", title: "Dispatch Queues"),
                gcdNote("gcd-03", file: "03 - async, sync, Ordering, and Execution Semantics", index: "03", title: "async, sync, and Ordering"),
                gcdNote("gcd-04", file: "04 - Quality of Service (QoS) and Priority", index: "04", title: "Quality of Service"),
                gcdNote("gcd-05", file: "05 - Protecting Shared State - Serial Queues and Barriers", index: "05", title: "Serial Queues and Barriers"),
                gcdNote("gcd-06", file: "06 - DispatchGroup, DispatchWorkItem, and DispatchSemaphore", index: "06", title: "Groups, Work Items, Semaphores"),
                gcdNote("gcd-07", file: "07 - Scheduling, Time, Queue Configuration, and Advanced APIs", index: "07", title: "Scheduling and Advanced APIs"),
                gcdNote("gcd-08", file: "08 - Memory Management, Closure Capture, and Autorelease Pools", index: "08", title: "Memory and Capture"),
                gcdNote("gcd-09", file: "09 - Race Conditions, Deadlocks, Thread Explosion, and Debugging", index: "09", title: "Races, Deadlocks, Debugging"),
                gcdNote("gcd-10", file: "10 - Practical iOS Patterns and Worked Examples", index: "10", title: "Practical iOS Patterns"),
                gcdNote("gcd-11", file: "11 - GCD and Modern Swift Concurrency", index: "11", title: "GCD and Swift Concurrency"),
                gcdNote("gcd-12", file: "12 - GCD Quick Reference and Interview Questions", index: "12", title: "Quick Reference"),
            ]
        )
    ]

    private static let modern: [CurriculumSection] = [
        CurriculumSection(
            id: "start",
            title: "Start here",
            notes: [
                modernNote("modern-overview", file: "README", folder: "Curriculum/Modern", index: "—", title: "Overview"),
                modernNote("modern-roadmap", file: "00 - Roadmap", folder: "Curriculum/Modern", index: "—", title: "Roadmap"),
                modernNote("modern-decision", file: "00 - Decision Procedure", folder: "Curriculum/Modern", index: "—", title: "Decision Procedure"),
                modernNote("modern-lab", file: "Lab Setup", folder: "Curriculum/Modern/Lab", index: "—", title: "Lab Setup"),
                modernNote("modern-progress", file: "Progress", folder: "Curriculum/Modern", index: "—", title: "Progress"),
            ]
        ),
        CurriculumSection(
            id: "modules",
            title: "Modules",
            notes: [
                modernNote("modern-01", file: "01 - Mental Model", folder: "Curriculum/Modern/Notes", index: "01", title: "Mental Model"),
                modernNote("modern-02", file: "02 - Async Await Deep Dive", folder: "Curriculum/Modern/Notes", index: "02", title: "async / await"),
                modernNote("modern-03", file: "03 - Isolation - The Core Concept", folder: "Curriculum/Modern/Notes", index: "03", title: "Isolation"),
                modernNote("modern-04", file: "04 - Actors", folder: "Curriculum/Modern/Notes", index: "04", title: "Actors"),
                modernNote("modern-05", file: "05 - MainActor and Global Actors", folder: "Curriculum/Modern/Notes", index: "05", title: "MainActor"),
                modernNote("modern-06", file: "06 - Sendable and Data-Race Safety", folder: "Curriculum/Modern/Notes", index: "06", title: "Sendable"),
                modernNote("modern-07", file: "07 - Bridging Legacy Code", folder: "Curriculum/Modern/Notes", index: "07", title: "Bridging Legacy Code"),
                modernNote("modern-08", file: "08 - Structured Concurrency", folder: "Curriculum/Modern/Notes", index: "08", title: "Structured Concurrency"),
                modernNote("modern-09", file: "09 - Tasks, Cancellation and Priority", folder: "Curriculum/Modern/Notes", index: "09", title: "Tasks and Cancellation"),
                modernNote("modern-10", file: "10 - AsyncSequence and AsyncStream", folder: "Curriculum/Modern/Notes", index: "10", title: "AsyncSequence"),
                modernNote("modern-11", file: "11 - Swift 6.2 and Modern Defaults", folder: "Curriculum/Modern/Notes", index: "11", title: "Swift 6.2 Defaults"),
                modernNote("modern-12", file: "12 - Migrating to Swift 6", folder: "Curriculum/Modern/Notes", index: "12", title: "Migrating to Swift 6"),
                modernNote("modern-13", file: "13 - Testing Concurrent Code", folder: "Curriculum/Modern/Notes", index: "13", title: "Testing Concurrent Code"),
            ]
        ),
        CurriculumSection(
            id: "reference",
            title: "Reference",
            notes: [
                modernNote("modern-glossary", file: "Glossary", folder: "Curriculum/Modern", index: "—", title: "Glossary"),
                modernNote("modern-resources", file: "Resources", folder: "Curriculum/Modern", index: "—", title: "Resources"),
            ]
        ),
        CurriculumSection(
            id: "drills",
            title: "Written drills",
            notes: [
                modernNote("modern-drills-how", file: "Drills - How They Work", folder: "Curriculum/Modern/Drills", index: "—", title: "How Drills Work"),
                modernNote("modern-drill-03", file: "Drill 03 - Reading Isolation", folder: "Curriculum/Modern/Drills", index: "03", title: "Reading Isolation"),
                modernNote("modern-drill-04", file: "Drill 04 - The Reentrancy Bug", folder: "Curriculum/Modern/Drills", index: "04", title: "The Reentrancy Bug"),
                modernNote("modern-drill-05", file: "Drill 05 - MainActor Propagation", folder: "Curriculum/Modern/Drills", index: "05", title: "MainActor Propagation"),
                modernNote("modern-drill-06", file: "Drill 06 - Making It Sendable", folder: "Curriculum/Modern/Drills", index: "06", title: "Making It Sendable"),
                modernNote("modern-drill-07", file: "Drill 07 - Wrap a Delegate", folder: "Curriculum/Modern/Drills", index: "07", title: "Wrap a Delegate"),
                modernNote("modern-drill-08", file: "Drill 08 - Parallel Fetch", folder: "Curriculum/Modern/Drills", index: "08", title: "Parallel Fetch"),
                modernNote("modern-drill-09", file: "Drill 09 - Cancel It Properly", folder: "Curriculum/Modern/Drills", index: "09", title: "Cancel It Properly"),
                modernNote("modern-drill-10", file: "Drill 10 - Build a Stream", folder: "Curriculum/Modern/Drills", index: "10", title: "Build a Stream"),
                modernNote("modern-drill-11", file: "Drill 11 - Same Code, Four Behaviours", folder: "Curriculum/Modern/Drills", index: "11", title: "Four Behaviours"),
                modernNote("modern-drill-12", file: "Drill 12 - Migrate One Module", folder: "Curriculum/Modern/Drills", index: "12", title: "Migrate One Module"),
                modernNote("modern-drill-13", file: "Drill 13 - Test the Untestable", folder: "Curriculum/Modern/Drills", index: "13", title: "Test the Untestable"),
                modernNote("modern-capstone", file: "Capstone", folder: "Curriculum/Modern/Drills", index: "—", title: "Capstone"),
            ]
        ),
    ]

    private static func gcdNote(_ id: String, file: String, index: String, title: String) -> CurriculumNote {
        CurriculumNote(
            id: id,
            indexLabel: index,
            title: title,
            fileName: file,
            subdirectory: "Curriculum/GCD"
        )
    }

    private static func modernNote(
        _ id: String,
        file: String,
        folder: String,
        index: String,
        title: String
    ) -> CurriculumNote {
        CurriculumNote(
            id: id,
            indexLabel: index,
            title: title,
            fileName: file,
            subdirectory: folder
        )
    }
}

enum CurriculumBundle {
    static func loadMarkdown(_ note: CurriculumNote) -> String {
        // Xcode's synchronized resource group flattens .md files into the bundle root.
        if let url = Bundle.main.url(forResource: note.fileName, withExtension: "md") {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? missing
        }
        if let url = Bundle.main.url(
            forResource: note.fileName,
            withExtension: "md",
            subdirectory: note.subdirectory
        ) {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? missing
        }
        return missing
    }

    private static let missing = "This note could not be loaded from the app bundle."
}

enum NoteMarkdown {
    static func prepared(_ raw: String, track: LearningTrack) -> String {
        let withoutEmbeds = rewriteObsidianEmbeds(raw)
        return mapOutsideCode(withoutEmbeds) { chunk in
            rewriteWikilinks(rewriteCallouts(chunk), track: track)
        }
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

    static func noteID(from url: URL) -> String? {
        guard url.scheme == "curriculum" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "id" })?.value
    }

    private static func noteURL(id: String) -> URL? {
        var components = URLComponents()
        components.scheme = "curriculum"
        components.host = "note"
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        return components.url
    }
}
