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
            id: "modules",
            title: "Modules",
            notes: [
                modernNote("modern-decision", file: "00 - Decision Procedure", folder: "Curriculum/Modern", index: "—", title: "Decision Procedure"),
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
