import SwiftUI

struct LandingView: View {
    @Binding var track: LearningTrack?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            DemoTheme.void.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LandingHeader()
                    if sizeClass == .compact {
                        VStack(spacing: 16) {
                            TrackDoor(track: .gcd) { track = .gcd }
                            TrackDoor(track: .modern) { track = .modern }
                        }
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            TrackDoor(track: .gcd) { track = .gcd }
                            TrackDoor(track: .modern) { track = .modern }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

private struct LandingHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Concurrency101")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(DemoTheme.phosphor)
            Text("Two runtimes. Same questions — who is waiting, does this touch the UI, can this overlap. Pick a world, then Playground, Notes, or Drill. Amber is the main thread; cyan is everything else.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TrackDoor: View {
    let track: LearningTrack
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                TrackGlyph(track: track)
                Text(track.title)
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.leading)
                Text(blurb)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Text(cta)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DemoTheme.void)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
            .padding(20)
            .background(Color.white.opacity(0.04))
            .overlay(
                Rectangle()
                    .strokeBorder(accent.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var accent: Color {
        track == .gcd ? DemoTheme.phosphor : DemoTheme.cyan
    }

    private var blurb: String {
        switch track {
        case .gcd:
            return "Queues, QoS, barriers, groups, and the kind of sync that parks a thread. Intent names map 1:1 onto Dispatch."
        case .modern:
            return "Tasks, actors, await, isolation, and cooperative cancel. Intent names map 1:1 onto Swift Concurrency."
        }
    }

    private var cta: String {
        switch track {
        case .gcd: return "Open GCD"
        case .modern: return "Open Swift Concurrency"
        }
    }
}

