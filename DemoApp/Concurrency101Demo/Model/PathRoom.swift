enum PathRoom: String, Hashable, Identifiable, CaseIterable {
    case playground
    case notes
    case drill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playground: return "Playground"
        case .notes: return "Notes"
        case .drill: return "Drill"
        }
    }

    func blurb(noteCount: Int) -> String {
        switch self {
        case .playground:
            return "Run the lessons. Watch work land on the glass console — the same lines Xcode prints."
        case .notes:
            return "The Obsidian curriculum for this path, \(noteCount) notes, with a sidebar to move between them."
        case .drill:
            return "Closed-book quizzes for this path. The quiz flow is next; playground and notes are ready now."
        }
    }

    var cta: String {
        switch self {
        case .playground: return "Open Playground"
        case .notes: return "Open Notes"
        case .drill: return "Coming next"
        }
    }

    var ctaOpacity: Double {
        self == .drill ? 0.55 : 1
    }
}
