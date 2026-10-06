import Foundation
import Observation

enum DrillPhase {
    case lobby
    case running
    case results
}

@MainActor
@Observable
final class DrillSession {
    let track: LearningTrack
    var difficulty: DrillDifficulty = .easy
    var phase: DrillPhase = .lobby
    var deck: [DrillPresentedQuestion] = []
    var index = 0
    var picks: [String: Int] = [:]
    var showExplain = false
    var isReview = false

    init(track: LearningTrack, snapshot: DrillRunSnapshot? = nil) {
        self.track = track
        if let snapshot {
            if let restored = Self.restored(track: track, snapshot: snapshot) {
                difficulty = restored.difficulty
                deck = restored.deck
                index = restored.index
                picks = restored.picks
                isReview = restored.isReview
                phase = .running
            } else {
                LearningMemory.clearDrill(track: track)
            }
        }
    }

    var current: DrillPresentedQuestion? {
        guard deck.indices.contains(index) else { return nil }
        return deck[index]
    }

    var currentPick: Int? {
        current.flatMap { picks[$0.id] }
    }

    var isLocked: Bool {
        currentPick != nil
    }

    var isFirst: Bool {
        index == 0
    }

    var isLast: Bool {
        !deck.isEmpty && index == deck.count - 1
    }

    var hits: Int {
        deck.reduce(into: 0) { count, card in
            if picks[card.id] == card.question.correctIndex {
                count += 1
            }
        }
    }

    var longestStreak: Int {
        var best = 0
        var run = 0
        for card in deck {
            if picks[card.id] == card.question.correctIndex {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    var lastScore: DrillLastScore? {
        DrillScoreStore.last(track: track, difficulty: difficulty)
    }

    var missedCards: [DrillPresentedQuestion] {
        deck.filter { picks[$0.id] != $0.question.correctIndex }
    }

    var hasSavedRun: Bool {
        LearningMemory.drillSnapshot(track: track) != nil
    }

    var pendingMissCount: Int {
        let missed = Set(LearningMemory.missedQuestionIDs(track: track))
        return DrillBank.questions(track: track, difficulty: difficulty).filter { missed.contains($0.id) }.count
    }

    func start() {
        deal()
        phase = .running
        persist()
    }

    func retry() {
        deal()
        phase = .running
        persist()
    }

    func resumeSaved() {
        guard let snapshot = LearningMemory.drillSnapshot(track: track) else { return }
        guard let restored = Self.restored(track: track, snapshot: snapshot) else {
            LearningMemory.clearDrill(track: track)
            return
        }
        difficulty = restored.difficulty
        deck = restored.deck
        index = restored.index
        picks = restored.picks
        isReview = restored.isReview
        showExplain = false
        phase = .running
    }

    func reviewMisses() {
        let wrong = missedCards
        guard !wrong.isEmpty else { return }
        deck = wrong
        index = 0
        picks = [:]
        showExplain = false
        isReview = true
        phase = .running
        persist()
    }

    func changeDifficulty() {
        showExplain = false
        phase = .lobby
        deck = []
        index = 0
        picks = [:]
        isReview = false
        LearningMemory.clearDrill(track: track)
    }

    func pick(_ originalIndex: Int) {
        guard let current, picks[current.id] == nil else { return }
        picks[current.id] = originalIndex
        let question = current.question
        if originalIndex == question.correctIndex {
            LearningMemory.resolveMiss(track: track, questionID: question.id)
        } else {
            LearningMemory.recordMiss(track: track, questionID: question.id)
            LearningMemory.appendMiss(
                track: track,
                miss: LearningMiss(
                    id: UUID(),
                    date: Date(),
                    module: question.sourceNote,
                    predicted: question.options[originalIndex],
                    actual: question.options[question.correctIndex],
                    why: question.explanation
                )
            )
        }
        persist()
    }

    func goPrevious() {
        guard !isFirst else { return }
        showExplain = false
        index -= 1
        persist()
    }

    func goNext() {
        guard isLocked else { return }
        showExplain = false
        if isLast {
            if !isReview {
                DrillScoreStore.save(hits: hits, total: deck.count, track: track, difficulty: difficulty)
            }
            phase = .results
            LearningMemory.clearDrill(track: track)
        } else {
            index += 1
            persist()
        }
    }

    private func deal() {
        let pool = DrillBank.questions(track: track, difficulty: difficulty)
        let missed = Set(LearningMemory.missedQuestionIDs(track: track))
        let preferred = pool.filter { missed.contains($0.id) }.shuffled()
        let others = pool.filter { !missed.contains($0.id) }.shuffled()
        let count = min(DrillBank.questionsPerRun, pool.count)
        deck = Array((preferred + others).prefix(count)).map { question in
            DrillPresentedQuestion(question: question, optionOrder: (0..<4).shuffled())
        }
        index = 0
        picks = [:]
        showExplain = false
        isReview = false
    }

    private func persist() {
        guard phase == .running, !deck.isEmpty else { return }
        LearningMemory.saveDrill(
            track: track,
            snapshot: DrillRunSnapshot(
                difficulty: difficulty.rawValue,
                questionIDs: deck.map(\.question.id),
                optionOrders: deck.map(\.optionOrder),
                picks: picks,
                index: index,
                isReview: isReview
            )
        )
    }

    private struct RestoredRun {
        var difficulty: DrillDifficulty
        var deck: [DrillPresentedQuestion]
        var index: Int
        var picks: [String: Int]
        var isReview: Bool
    }

    private static func restored(track: LearningTrack, snapshot: DrillRunSnapshot) -> RestoredRun? {
        guard let difficulty = DrillDifficulty(rawValue: snapshot.difficulty) else { return nil }
        guard snapshot.questionIDs.count == snapshot.optionOrders.count, !snapshot.questionIDs.isEmpty else {
            return nil
        }
        var deck: [DrillPresentedQuestion] = []
        for (offset, id) in snapshot.questionIDs.enumerated() {
            guard let question = DrillBank.question(id: id, track: track) else { continue }
            let order = snapshot.optionOrders[offset]
            guard order.count == 4, Set(order) == Set(0..<4) else { continue }
            deck.append(DrillPresentedQuestion(question: question, optionOrder: order))
        }
        guard !deck.isEmpty else { return nil }
        let index = min(max(snapshot.index, 0), deck.count - 1)
        let liveIDs = Set(deck.map(\.id))
        let picks = snapshot.picks.filter { liveIDs.contains($0.key) }
        return RestoredRun(
            difficulty: difficulty,
            deck: deck,
            index: index,
            picks: picks,
            isReview: snapshot.isReview
        )
    }
}
