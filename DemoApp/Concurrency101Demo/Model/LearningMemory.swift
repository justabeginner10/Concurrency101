import Foundation

struct LearningContinue: Equatable {
    enum Kind: Equatable {
        case notes
        case playground
        case drill
    }

    var kind: Kind
    var title: String
    var subtitle: String
    var noteID: String?
    var lessonID: String?
}

struct LearningMiss: Codable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    var module: String
    var predicted: String
    var actual: String
    var why: String
}

struct DrillRunSnapshot: Codable, Equatable {
    var difficulty: String
    var questionIDs: [String]
    var optionOrders: [[Int]]
    var picks: [String: Int]
    var index: Int
    var isReview: Bool
}

enum LearningMemory {
    private static let missCap = 40

    static func continueTarget(track: LearningTrack) -> LearningContinue? {
        if let drill = drillSnapshot(track: track), !drill.questionIDs.isEmpty {
            let current = min(drill.index + 1, drill.questionIDs.count)
            return LearningContinue(
                kind: .drill,
                title: "Drill",
                subtitle: "Question \(current) of \(drill.questionIDs.count)",
                noteID: nil,
                lessonID: nil
            )
        }

        let noteDate = date(forKey: noteDateKey(track))
        let lessonDate = date(forKey: lessonDateKey(track))
        if noteDate == nil, lessonDate == nil { return nil }

        if (noteDate ?? .distantPast) >= (lessonDate ?? .distantPast),
           let id = string(forKey: noteIDKey(track)),
           let title = string(forKey: noteTitleKey(track)) {
            return LearningContinue(
                kind: .notes,
                title: "Notes",
                subtitle: title,
                noteID: id,
                lessonID: nil
            )
        }

        if let id = string(forKey: lessonIDKey(track)),
           let title = string(forKey: lessonTitleKey(track)) {
            return LearningContinue(
                kind: .playground,
                title: "Playground",
                subtitle: title,
                noteID: nil,
                lessonID: id
            )
        }
        return nil
    }

    static func lastNoteID(track: LearningTrack) -> String? {
        string(forKey: noteIDKey(track))
    }

    static func lastLessonID(track: LearningTrack) -> String? {
        string(forKey: lessonIDKey(track))
    }

    static func rememberNote(track: LearningTrack, id: String, title: String) {
        defaults.set(id, forKey: noteIDKey(track))
        defaults.set(title, forKey: noteTitleKey(track))
        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: noteDateKey(track))
        markOpenedNote(track: track, id: id)
    }

    static func rememberLesson(track: LearningTrack, id: String, title: String) {
        defaults.set(id, forKey: lessonIDKey(track))
        defaults.set(title, forKey: lessonTitleKey(track))
        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: lessonDateKey(track))
    }

    static func openedNoteIDs(track: LearningTrack) -> Set<String> {
        Set(strings(forKey: openedNotesKey(track)))
    }

    static func ranLessonIDs(track: LearningTrack) -> Set<String> {
        Set(strings(forKey: ranLessonsKey(track)))
    }

    static func markLessonRun(track: LearningTrack, id: String) {
        var ids = strings(forKey: ranLessonsKey(track))
        if !ids.contains(id) {
            ids.append(id)
            store(ids, forKey: ranLessonsKey(track))
        }
    }

    static func missedQuestionIDs(track: LearningTrack) -> [String] {
        strings(forKey: missesKey(track))
    }

    static func recordMiss(track: LearningTrack, questionID: String) {
        var ids = strings(forKey: missesKey(track))
        ids.removeAll { $0 == questionID }
        ids.insert(questionID, at: 0)
        store(ids, forKey: missesKey(track))
    }

    static func resolveMiss(track: LearningTrack, questionID: String) {
        var ids = strings(forKey: missesKey(track))
        ids.removeAll { $0 == questionID }
        store(ids, forKey: missesKey(track))
    }

    static func drillSnapshot(track: LearningTrack) -> DrillRunSnapshot? {
        guard let data = defaults.data(forKey: drillKey(track)) else { return nil }
        return try? JSONDecoder().decode(DrillRunSnapshot.self, from: data)
    }

    static func saveDrill(track: LearningTrack, snapshot: DrillRunSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: drillKey(track))
    }

    static func clearDrill(track: LearningTrack) {
        defaults.removeObject(forKey: drillKey(track))
    }

    static func errorLog(track: LearningTrack) -> [LearningMiss] {
        guard let data = defaults.data(forKey: errorLogKey(track)) else { return [] }
        return (try? JSONDecoder().decode([LearningMiss].self, from: data)) ?? []
    }

    static func appendMiss(track: LearningTrack, miss: LearningMiss) {
        var entries = errorLog(track: track)
        entries.insert(miss, at: 0)
        if entries.count > missCap {
            entries = Array(entries.prefix(missCap))
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: errorLogKey(track))
    }

    private static func markOpenedNote(track: LearningTrack, id: String) {
        var ids = strings(forKey: openedNotesKey(track))
        if !ids.contains(id) {
            ids.append(id)
            store(ids, forKey: openedNotesKey(track))
        }
    }

    private static let defaults = UserDefaults.standard

    private static func noteIDKey(_ track: LearningTrack) -> String { "learn.note.id.\(track.rawValue)" }
    private static func noteTitleKey(_ track: LearningTrack) -> String { "learn.note.title.\(track.rawValue)" }
    private static func noteDateKey(_ track: LearningTrack) -> String { "learn.note.date.\(track.rawValue)" }
    private static func lessonIDKey(_ track: LearningTrack) -> String { "learn.lesson.id.\(track.rawValue)" }
    private static func lessonTitleKey(_ track: LearningTrack) -> String { "learn.lesson.title.\(track.rawValue)" }
    private static func lessonDateKey(_ track: LearningTrack) -> String { "learn.lesson.date.\(track.rawValue)" }
    private static func openedNotesKey(_ track: LearningTrack) -> String { "learn.opened.\(track.rawValue)" }
    private static func ranLessonsKey(_ track: LearningTrack) -> String { "learn.ran.\(track.rawValue)" }
    private static func missesKey(_ track: LearningTrack) -> String { "learn.misses.\(track.rawValue)" }
    private static func drillKey(_ track: LearningTrack) -> String { "learn.drill.\(track.rawValue)" }
    private static func errorLogKey(_ track: LearningTrack) -> String { "learn.errors.\(track.rawValue)" }

    private static func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    private static func date(forKey key: String) -> Date? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSinceReferenceDate: defaults.double(forKey: key))
    }

    private static func strings(forKey key: String) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    private static func store(_ values: [String], forKey key: String) {
        defaults.set(values, forKey: key)
    }
}
