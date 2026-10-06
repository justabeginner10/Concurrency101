import SwiftUI

struct DrillResultsView: View {
    @Bindable var session: DrillSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DrillGlyph(accent: session.track.accent)
                Text("Results")
                    .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                    .foregroundStyle(session.track.accent)
                Text(verbatim: session.difficulty.title)
                    .font(.system(size: DemoLayout.typeSize(14), design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)

                VStack(alignment: .leading, spacing: 10) {
                    DrillResultRow(
                        label: "Hits",
                        value: "\(session.hits) / \(session.deck.count)",
                        accent: session.track.accent
                    )
                    DrillResultRow(
                        label: "Longest streak",
                        value: "\(session.longestStreak)",
                        accent: session.track.accent
                    )
                }

                Button {
                    session.retry()
                } label: {
                    Text("Retry")
                        .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(session.track.accent)
                        .foregroundStyle(DemoTheme.void)
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(.top, 8)

                Button {
                    session.changeDifficulty()
                } label: {
                    HStack(spacing: 8) {
                        Text("Change difficulty")
                        Image(systemName: "chevron.right")
                            .font(.system(size: DemoLayout.typeSize(12), weight: .semibold))
                    }
                    .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(session.track.accent)
                    .background(session.track.accent.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(session.track.accent, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }
}

private struct DrillResultRow: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack {
            Text(verbatim: label)
                .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                .foregroundStyle(Color.white.opacity(0.78))
            Spacer()
            Text(verbatim: value)
                .font(.system(size: DemoLayout.typeSize(16), design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .overlay(
            Rectangle()
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        )
    }
}
