import SwiftUI

struct TrackHubView: View {
    let track: LearningTrack
    @State private var room: PathRoom?
    @Environment(\.usesPhoneChrome) private var usesPhoneChrome
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var noteCount: Int {
        CurriculumCatalog.notes(for: track).count
    }

    var body: some View {
        DemoCanvas {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TrackHubHeader(trackTitle: track.title, accent: track.accent)
                    AdaptiveCardStack(usesPhoneChrome: usesPhoneChrome) {
                        ForEach(PathRoom.allCases) { room in
                            PathRoomCard(
                                room: room,
                                track: track,
                                noteCount: noteCount,
                                compactVertical: verticalSizeClass == .compact
                            ) {
                                self.room = room
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(track.hubNavigationTitle)
        .demoRoomChrome()
        .navigationDestination(item: $room) { selected in
            switch selected {
            case .playground:
                WorkbenchView(track: track)
            case .notes:
                NotesStudioView(track: track)
            case .drill:
                DrillView(track: track)
            }
        }
    }
}

private struct TrackHubHeader: View {
    let trackTitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: trackTitle)
                .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                .foregroundStyle(accent)
            Text("Three rooms. Playground runs the lessons. Notes is the curriculum. Drill is the closed-book quiz.")
                .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PathRoomCard: View {
    let room: PathRoom
    let track: LearningTrack
    let noteCount: Int
    var compactVertical: Bool = false
    let action: () -> Void

    var body: some View {
        ChoiceCard(
            title: room.title,
            blurb: room.blurb(noteCount: noteCount),
            cta: room.cta,
            accent: track.accent,
            ctaOpacity: room.ctaOpacity,
            compactVertical: compactVertical,
            minHeight: compactVertical ? 160 : 240,
            action: action
        ) {
            PathRoomGlyph(room: room, track: track)
        }
    }
}
