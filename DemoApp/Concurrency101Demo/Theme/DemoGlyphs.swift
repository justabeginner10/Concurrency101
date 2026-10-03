import SwiftUI

/// GCD = stacked FIFO lanes. Swift = a line that suspends, then continues.
struct TrackGlyph: View {
    let track: LearningTrack

    var body: some View {
        Group {
            if track == .gcd {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(DemoTheme.phosphor.opacity(index == 1 ? 0.95 : 0.28))
                            .frame(width: index == 1 ? 92 : 70, height: 5)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    Capsule()
                        .fill(DemoTheme.cyan)
                        .frame(width: 44, height: 5)
                    Circle()
                        .strokeBorder(DemoTheme.cyan, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    Capsule()
                        .fill(DemoTheme.cyan.opacity(0.35))
                        .frame(width: 36, height: 5)
                }
            }
        }
        .frame(height: 36, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct NotesGlyph: View {
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(accent.opacity(index == 0 ? 0.95 : index == 3 ? 0.22 : 0.45))
                    .frame(width: index == 0 ? 86 : index == 3 ? 48 : 72, height: 4)
            }
        }
        .padding(.leading, 8)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: 2, height: 36)
        }
        .frame(height: 36, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct DrillGlyph: View {
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(accent.opacity(0.35), lineWidth: 1.5)
                .frame(width: 34, height: 34)
            Circle()
                .strokeBorder(accent, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
        }
        .frame(height: 36, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct PathRoomGlyph: View {
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
