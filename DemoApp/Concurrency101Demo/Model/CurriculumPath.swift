import Foundation

struct CurriculumPathStep: Identifiable, Hashable {
    var id: String
    var indexLabel: String
    var title: String
    var noteID: String
    var lessonIDs: [String]
    var practiceNoteID: String?
    var practiceTitle: String?
}

enum CurriculumPath {
    static func steps(for track: LearningTrack) -> [CurriculumPathStep] {
        switch track {
        case .gcd: return gcd
        case .modern: return modern
        }
    }

    static func lessonTitle(_ id: String, track: LearningTrack) -> String? {
        ScenarioLibrary.scenarios(for: track).first { $0.id == id }?.title
    }

    private static let modern: [CurriculumPathStep] = [
        step("modern-roadmap", "00", "Roadmap", note: "modern-roadmap"),
        step("modern-01", "01", "Mental Model", note: "modern-01", lessons: ["modern-await-vs-block"]),
        step("modern-02", "02", "async / await", note: "modern-02", lessons: ["modern-delayed-ui"]),
        step("modern-03", "03", "Isolation", note: "modern-03", lessons: ["modern-detached", "modern-decode-ui"], practice: "modern-drill-03", practiceTitle: "Reading Isolation"),
        step("modern-04", "04", "Actors", note: "modern-04", lessons: ["modern-actor", "modern-reentrancy"], practice: "modern-drill-04", practiceTitle: "The Reentrancy Bug"),
        step("modern-05", "05", "MainActor", note: "modern-05", lessons: ["modern-immediate", "modern-deadlock"], practice: "modern-drill-05", practiceTitle: "MainActor Propagation"),
        step("modern-06", "06", "Sendable", note: "modern-06", lessons: ["modern-actor"], practice: "modern-drill-06", practiceTitle: "Making It Sendable"),
        step("modern-07", "07", "Bridging", note: "modern-07", lessons: ["modern-continuation"], practice: "modern-drill-07", practiceTitle: "Wrap a Delegate"),
        step("modern-08", "08", "Structured Concurrency", note: "modern-08", lessons: ["modern-group", "modern-async-let"], practice: "modern-drill-08", practiceTitle: "Parallel Fetch"),
        step("modern-09", "09", "Tasks and Cancellation", note: "modern-09", lessons: ["modern-cancel-sleep", "modern-cancel-busy", "modern-priority"], practice: "modern-drill-09", practiceTitle: "Cancel It Properly"),
        step("modern-10", "10", "AsyncSequence", note: "modern-10", practice: "modern-drill-10", practiceTitle: "Build a Stream"),
        step("modern-11", "11", "Swift 6.2 Defaults", note: "modern-11", practice: "modern-drill-11", practiceTitle: "Same Code, Four Behaviours"),
        step("modern-12", "12", "Migrating to Swift 6", note: "modern-12", practice: "modern-drill-12", practiceTitle: "Migrate One Module"),
        step("modern-13", "13", "Testing", note: "modern-13", practice: "modern-drill-13", practiceTitle: "Test the Untestable"),
        step("modern-capstone", "—", "Capstone", note: "modern-capstone"),
    ]

    private static let gcd: [CurriculumPathStep] = [
        step("gcd-00", "00", "Index", note: "gcd-00"),
        step("gcd-01", "01", "Mental Model", note: "gcd-01", lessons: ["update-ui"]),
        step("gcd-02", "02", "Dispatch Queues", note: "gcd-02", lessons: ["serial-race", "overlap"]),
        step("gcd-03", "03", "async, sync, and Ordering", note: "gcd-03", lessons: ["sync-safe", "deadlock"]),
        step("gcd-04", "04", "Quality of Service", note: "gcd-04", lessons: ["qos-names", "immediate-ui", "maintenance"]),
        step("gcd-05", "05", "Serial Queues and Barriers", note: "gcd-05", lessons: ["barrier"]),
        step("gcd-06", "06", "Groups, Work Items, Semaphores", note: "gcd-06", lessons: ["group-notify", "missing-leave", "enter-leave", "work-item", "wait-timeout"]),
        step("gcd-07", "07", "Scheduling", note: "gcd-07", lessons: ["delayed-ui"]),
        step("gcd-08", "08", "Memory and Capture", note: "gcd-08"),
        step("gcd-09", "09", "Races, Deadlocks, Debugging", note: "gcd-09", lessons: ["deadlock", "serial-race"]),
        step("gcd-10", "10", "Practical iOS Patterns", note: "gcd-10", lessons: ["update-ui"]),
        step("gcd-11", "11", "GCD and Swift Concurrency", note: "gcd-11"),
        step("gcd-12", "12", "Quick Reference", note: "gcd-12"),
    ]

    private static func step(
        _ id: String,
        _ index: String,
        _ title: String,
        note: String,
        lessons: [String] = [],
        practice: String? = nil,
        practiceTitle: String? = nil
    ) -> CurriculumPathStep {
        CurriculumPathStep(
            id: id,
            indexLabel: index,
            title: title,
            noteID: note,
            lessonIDs: lessons,
            practiceNoteID: practice,
            practiceTitle: practiceTitle
        )
    }
}
