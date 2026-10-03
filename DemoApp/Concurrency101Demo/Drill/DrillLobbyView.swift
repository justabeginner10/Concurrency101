import SwiftUI

struct DrillLobbyView: View {
    @Bindable var session: DrillSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DrillGlyph(accent: session.track.accent)
                Text("Drill")
                    .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                    .foregroundStyle(session.track.accent)
                Text(verbatim: session.track.title)
                    .font(.system(size: DemoLayout.typeSize(14), design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)
                Text("Closed-book. Four options. You find out immediately. Explanations stay on a sheet.")
                    .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(DrillDifficulty.allCases) { lane in
                        DrillDifficultyRow(
                            title: lane.title,
                            blurb: lane.blurb,
                            isSelected: session.difficulty == lane,
                            accent: session.track.accent
                        ) {
                            session.difficulty = lane
                        }
                    }
                }

                if let last = session.lastScore {
                    Text("Last \(session.difficulty.title) run: \(last.hits) / \(last.total)")
                        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                        .foregroundStyle(DemoTheme.muted)
                }

                Button {
                    session.start()
                } label: {
                    Text("Start")
                        .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(session.track.accent)
                        .foregroundStyle(DemoTheme.void)
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }
}

private struct DrillDifficultyRow: View {
    let title: String
    let blurb: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: title)
                    .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                    .foregroundStyle(isSelected ? DemoTheme.void : accent)
                Text(verbatim: blurb)
                    .font(.system(size: DemoLayout.typeSize(13), design: .serif))
                    .foregroundStyle(isSelected ? DemoTheme.void.opacity(0.78) : Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? accent : Color.white.opacity(0.04))
            .overlay(
                Rectangle()
                    .strokeBorder(accent.opacity(isSelected ? 0 : 0.28), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
