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
        ZStack {
            DemoTheme.void.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TrackHubHeader(trackTitle: track.title, accent: track.accent)
                    PathRoomStack(
                        track: track,
                        usesPhoneChrome: usesPhoneChrome,
                        compactVertical: verticalSizeClass == .compact,
                        noteCount: noteCount
                    ) { selected in
                        room = selected
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(track.hubNavigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(DemoTheme.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .navigationDestination(item: $room) { selected in
            switch selected {
            case .playground:
                WorkbenchView(track: track)
            case .notes:
                NotesStudioView(track: track)
            case .drill:
                DrillComingSoonView(track: track)
            }
        }
    }
}

private struct PathRoomStack: View {
    let track: LearningTrack
    let usesPhoneChrome: Bool
    let compactVertical: Bool
    let noteCount: Int
    let onSelect: (PathRoom) -> Void

    var body: some View {
        let cards = Group {
            PathRoomCard(room: .playground, track: track, noteCount: noteCount, compactVertical: compactVertical) {
                onSelect(.playground)
            }
            PathRoomCard(room: .notes, track: track, noteCount: noteCount, compactVertical: compactVertical) {
                onSelect(.notes)
            }
            PathRoomCard(room: .drill, track: track, noteCount: noteCount, compactVertical: compactVertical) {
                onSelect(.drill)
            }
        }
        if usesPhoneChrome {
            VStack(spacing: 16) { cards }
        } else {
            HStack(alignment: .top, spacing: 16) { cards }
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
            Text("Three rooms. Playground runs the lessons. Notes is the curriculum. Drill will be the quiz — not in this build.")
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
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                PathRoomGlyph(room: room, track: track)
                Text(verbatim: room.title)
                    .font(.system(size: DemoLayout.typeSize(22), design: .serif))
                    .foregroundStyle(track.accent)
                    .multilineTextAlignment(.leading)
                Text(verbatim: room.blurb(noteCount: noteCount))
                    .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(compactVertical ? 3 : nil)
                    .fixedSize(horizontal: false, vertical: !compactVertical)
                    .multilineTextAlignment(.leading)
                Text(verbatim: room.cta)
                    .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                    .foregroundStyle(DemoTheme.void)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(track.accent.opacity(room == .drill ? 0.55 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .frame(maxWidth: .infinity, minHeight: compactVertical ? 160 : 240, alignment: .topLeading)
            .padding(20)
            .background(Color.white.opacity(0.04))
            .overlay(
                Rectangle()
                    .strokeBorder(track.accent.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(room.title)
        .accessibilityHint(room.cta)
    }
}

private struct PathRoomGlyph: View {
    let room: PathRoom
    let track: LearningTrack

    var body: some View {
        switch room {
        case .playground:
            TrackGlyph(track: track)
        case .notes:
            NotesGlyph(accent: track.accent)
        case .drill:
            DrillGlyph(accent: track.accent)
        }
    }
}
