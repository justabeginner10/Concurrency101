import SwiftUI

struct DrillView: View {
    let track: LearningTrack
    @State private var session: DrillSession
    @State private var confirmLeave = false
    @Environment(\.dismiss) private var dismiss

    init(track: LearningTrack) {
        self.track = track
        _session = State(initialValue: DrillSession(track: track))
    }

    private var quizIsRunning: Bool {
        session.phase == .running
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
        .navigationBarBackButtonHidden(quizIsRunning)
        .navigationPopGestureDisabled(quizIsRunning)
        .toolbar {
            if quizIsRunning {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        confirmLeave = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text(verbatim: track.hubNavigationTitle)
                        }
                    }
                    .foregroundStyle(track.accent)
                }
            }
        }
        .alert("Are you sure you want to go back?", isPresented: $confirmLeave) {
            Button("Yes") { dismiss() }
            Button("No", role: .cancel) {}
        }
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
