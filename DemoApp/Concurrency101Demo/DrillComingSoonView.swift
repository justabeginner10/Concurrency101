import SwiftUI

struct DrillComingSoonView: View {
    let track: LearningTrack

    var body: some View {
        ZStack {
            DemoTheme.void.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DrillGlyph(accent: track.accent)
                    Text("Drill")
                        .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                        .foregroundStyle(track.accent)
                    Text(verbatim: track.title)
                        .font(.system(size: DemoLayout.typeSize(14), design: .monospaced))
                        .foregroundStyle(DemoTheme.muted)
                    Text("This room will be a quiz: short questions, then an explanation. It is not in this build. Use Playground to run the lessons and Notes to read the curriculum.")
                        .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 10) {
                        DrillSoonRow(index: "01", title: "Playground is ready", accent: track.accent)
                        DrillSoonRow(index: "02", title: "Notes is ready", accent: track.accent)
                        DrillSoonRow(index: "03", title: "Drill arrives next", accent: track.accent)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
        .navigationTitle("Drill")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(DemoTheme.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
    }
}

private struct DrillSoonRow: View {
    let index: String
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: index)
                .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                .foregroundStyle(accent)
                .frame(width: 28, alignment: .leading)
            Text(verbatim: title)
                .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                .foregroundStyle(Color.white.opacity(0.86))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .overlay(
            Rectangle()
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        )
    }
}
