import SwiftUI

struct DrillView: View {
    let track: LearningTrack
    @State private var session: DrillSession

    init(track: LearningTrack) {
        self.track = track
        _session = State(initialValue: DrillSession(track: track))
    }

    var body: some View {
        DemoCanvas {
            switch session.phase {
            case .lobby:
                DrillLobbyView(session: session)
            case .running:
                DrillQuestionView(session: session)
            case .results:
                DrillResultsView(session: session)
            }
        }
        .navigationTitle(title)
        .demoRoomChrome()
    }

    private var title: String {
        switch session.phase {
        case .lobby, .results:
            return "Drill"
        case .running:
            return "\(session.index + 1) / \(session.deck.count)"
        }
    }
}
