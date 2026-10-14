import Foundation

enum DrillDifficulty: String, CaseIterable, Identifiable, Hashable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var blurb: String {
        switch self {
        case .easy:
            return "One named rule. Definitions and distinctions the notes already hammer."
        case .medium:
            return "Apply that rule to a short snippet. Predict the outcome."
        case .hard:
            return "Two rules at once, or the Swift 6.2 default people still have wrong."
        }
    }
}

struct DrillQuestion: Identifiable, Hashable {
    var id: String
    var track: LearningTrack
    var difficulty: DrillDifficulty
    var sourceNote: String
    var stem: String
    var snippet: String?
    var options: [String]
    var correctIndex: Int
    var explanation: String

    init(
        id: String,
        track: LearningTrack,
        difficulty: DrillDifficulty,
        sourceNote: String,
        stem: String,
        snippet: String? = nil,
        options: [String],
        correctIndex: Int = 0,
        explanation: String
    ) {
        precondition(options.count == 4, "Every drill card has exactly four options.")
        precondition((0..<4).contains(correctIndex), "correctIndex must point at one of the four options.")
        self.id = id
        self.track = track
        self.difficulty = difficulty
        self.sourceNote = sourceNote
        self.stem = stem
        self.snippet = snippet
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}

struct DrillPresentedOption: Identifiable, Hashable {
    let originalIndex: Int
    let text: String

    var id: Int { originalIndex }
}

struct DrillPresentedQuestion: Identifiable, Hashable {
    let question: DrillQuestion
    let optionOrder: [Int]

    var id: String { question.id }

    var presentedOptions: [DrillPresentedOption] {
        optionOrder.map { index in
            DrillPresentedOption(originalIndex: index, text: question.options[index])
        }
    }
}

struct DrillLastScore: Equatable {
    var hits: Int
    var total: Int
}

enum DrillScoreStore {
    static func last(track: LearningTrack, difficulty: DrillDifficulty) -> DrillLastScore? {
        let hits = UserDefaults.standard.object(forKey: hitsKey(track: track, difficulty: difficulty)) as? Int
        let total = UserDefaults.standard.object(forKey: totalKey(track: track, difficulty: difficulty)) as? Int
        guard let hits, let total, total > 0 else { return nil }
        return DrillLastScore(hits: hits, total: total)
    }

    static func save(hits: Int, total: Int, track: LearningTrack, difficulty: DrillDifficulty) {
        UserDefaults.standard.set(hits, forKey: hitsKey(track: track, difficulty: difficulty))
        UserDefaults.standard.set(total, forKey: totalKey(track: track, difficulty: difficulty))
    }

    private static func hitsKey(track: LearningTrack, difficulty: DrillDifficulty) -> String {
        "drill.score.hits.\(track.rawValue).\(difficulty.rawValue)"
    }

    private static func totalKey(track: LearningTrack, difficulty: DrillDifficulty) -> String {
        "drill.score.total.\(track.rawValue).\(difficulty.rawValue)"
    }
}

enum DrillBank {
    static let questionsPerRun = 8

    static func questions(track: LearningTrack, difficulty: DrillDifficulty) -> [DrillQuestion] {
        source(for: track).filter { $0.difficulty == difficulty }
    }

    static func question(id: String, track: LearningTrack) -> DrillQuestion? {
        source(for: track).first { $0.id == id }
    }

    private static func source(for track: LearningTrack) -> [DrillQuestion] {
        switch track {
        case .gcd: return DrillQuestionsGCD.all
        case .modern: return DrillQuestionsSwift.all
        }
    }
}
