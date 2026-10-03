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

    init(track: LearningTrack) {
        self.track = track
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

    func start() {
        deal()
        phase = .running
    }

    func retry() {
        deal()
        phase = .running
    }

    func changeDifficulty() {
        showExplain = false
        phase = .lobby
        deck = []
        index = 0
        picks = [:]
    }

    func pick(_ originalIndex: Int) {
        guard let current, picks[current.id] == nil else { return }
        picks[current.id] = originalIndex
    }

    func goPrevious() {
        guard !isFirst else { return }
        showExplain = false
        index -= 1
    }

    func goNext() {
        guard isLocked else { return }
        showExplain = false
        if isLast {
            DrillScoreStore.save(hits: hits, total: deck.count, track: track, difficulty: difficulty)
            phase = .results
        } else {
            index += 1
        }
    }

    private func deal() {
        let pool = DrillBank.questions(track: track, difficulty: difficulty)
        let count = min(DrillBank.questionsPerRun, pool.count)
        deck = Array(pool.shuffled().prefix(count)).map { question in
            DrillPresentedQuestion(question: question, optionOrder: (0..<4).shuffled())
        }
        index = 0
        picks = [:]
        showExplain = false
    }
}
