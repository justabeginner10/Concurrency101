import SwiftUI

struct ErrorLogView: View {
    let track: LearningTrack
    @State private var entries: [LearningMiss] = []

    var body: some View {
        DemoCanvas {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Error log")
                        .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                        .foregroundStyle(track.accent)
                    Text("What you predicted, what happened, and why. A wrong drill answer or a playground prediction lands here.")
                        .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    if entries.isEmpty {
                        Text("Nothing here yet.")
                            .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                            .foregroundStyle(DemoTheme.muted)
                            .padding(.top, 8)
                    } else {
                        ForEach(entries) { entry in
                            ErrorLogRow(entry: entry, accent: track.accent)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: 720, alignment: .leading)
            }
        }
        .navigationTitle("Error log")
        .demoRoomChrome()
        .onAppear {
            entries = LearningMemory.errorLog(track: track)
        }
    }
}

private struct ErrorLogRow: View {
    let entry: LearningMiss
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: entry.module)
                    .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)
            }
            labeled("Predicted", entry.predicted)
            labeled("Actually", entry.actual)
            Text(verbatim: entry.why)
                .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .overlay {
            Rectangle()
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                .foregroundStyle(DemoTheme.muted)
            Text(verbatim: value)
                .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
