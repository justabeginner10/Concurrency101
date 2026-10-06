import SwiftUI

private enum HubDestination: Hashable {
    case playground(String?)
    case notes(String?)
    case drill(Bool)
    case errorLog
}

struct TrackHubView: View {
    let track: LearningTrack
    @State private var destination: HubDestination?
    @State private var continueTarget: LearningContinue?
    @State private var openedNoteIDs: Set<String> = []
    @State private var ranLessonIDs: Set<String> = []
    @State private var errorCount = 0
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
                    if let continueTarget {
                        ContinueButton(target: continueTarget, accent: track.accent) {
                            open(continueTarget)
                        }
                    }
                    AdaptiveCardStack(usesPhoneChrome: usesPhoneChrome) {
                        ForEach(PathRoom.allCases) { room in
                            PathRoomCard(
                                room: room,
                                track: track,
                                noteCount: noteCount,
                                compactVertical: verticalSizeClass == .compact
                            ) {
                                open(room)
                            }
                        }
                    }
                    PathSectionView(
                        track: track,
                        openedNoteIDs: openedNoteIDs,
                        ranLessonIDs: ranLessonIDs,
                        onOpenNote: { destination = .notes($0) },
                        onOpenLesson: { destination = .playground($0) },
                        onOpenDrill: { destination = .drill(false) }
                    )
                    ErrorLogLink(count: errorCount, accent: track.accent) {
                        destination = .errorLog
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(track.hubNavigationTitle)
        .demoRoomChrome()
        .onAppear(perform: reload)
        .navigationDestination(item: $destination) { selected in
            switch selected {
            case .playground(let lessonID):
                WorkbenchView(track: track, initialLessonID: lessonID)
            case .notes(let noteID):
                NotesStudioView(track: track, initialNoteID: noteID)
            case .drill(let resume):
                DrillView(track: track, resume: resume)
            case .errorLog:
                ErrorLogView(track: track)
            }
        }
    }

    private func reload() {
        continueTarget = LearningMemory.continueTarget(track: track)
        openedNoteIDs = LearningMemory.openedNoteIDs(track: track)
        ranLessonIDs = LearningMemory.ranLessonIDs(track: track)
        errorCount = LearningMemory.errorLog(track: track).count
    }

    private func open(_ room: PathRoom) {
        switch room {
        case .playground:
            destination = .playground(nil)
        case .notes:
            destination = .notes(nil)
        case .drill:
            destination = .drill(false)
        }
    }

    private func open(_ target: LearningContinue) {
        switch target.kind {
        case .notes:
            destination = .notes(target.noteID)
        case .playground:
            destination = .playground(target.lessonID)
        case .drill:
            destination = .drill(true)
        }
    }
}

private struct ContinueButton: View {
    let target: LearningContinue
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue")
                        .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                        .foregroundStyle(accent)
                    Text(verbatim: target.subtitle)
                        .font(.system(size: DemoLayout.typeSize(18), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .multilineTextAlignment(.leading)
                    Text(verbatim: target.title)
                        .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                        .foregroundStyle(DemoTheme.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(accent, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ErrorLogLink: View {
    let count: Int
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error log")
                        .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                        .foregroundStyle(accent)
                    Text(count == 0 ? "Misses land here." : "\(count) \(count == 1 ? "miss" : "misses")")
                        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                        .foregroundStyle(DemoTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .overlay {
                Rectangle()
                    .strokeBorder(accent.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
