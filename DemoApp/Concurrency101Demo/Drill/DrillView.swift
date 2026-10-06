import SwiftUI

struct DrillView: View {
    let track: LearningTrack
    @State private var session: DrillSession
    @State private var confirmLeave = false
    @State private var noteID: String?
    @Environment(\.dismiss) private var dismiss

    init(track: LearningTrack, resume: Bool = false) {
        self.track = track
        let snapshot = resume ? LearningMemory.drillSnapshot(track: track) : nil
        _session = State(initialValue: DrillSession(track: track, snapshot: snapshot))
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
                DrillQuestionView(session: session) { id in
                    noteID = id
                }
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
                ToolbarItem(placement: Self.backButtonPlacement) {
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
        .navigationDestination(item: $noteID) { id in
            NotesStudioView(track: track, initialNoteID: id)
        }
    }

    /// `.topBarLeading` is iOS-only; `.navigation` is the leading slot on macOS.
    private static var backButtonPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
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
