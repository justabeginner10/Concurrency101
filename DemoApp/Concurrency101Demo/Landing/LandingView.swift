import SwiftUI

struct LandingView: View {
    @Binding var track: LearningTrack?
    @Environment(\.usesPhoneChrome) private var usesPhoneChrome
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        DemoCanvas {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LandingHeader()
                    AdaptiveCardStack(usesPhoneChrome: usesPhoneChrome) {
                        TrackDoor(track: .gcd, compactVertical: compactVertical) { track = .gcd }
                        TrackDoor(track: .modern, compactVertical: compactVertical) { track = .modern }
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

    private var compactVertical: Bool {
        !usesPhoneChrome && verticalSizeClass == .compact
    }
}

private struct LandingHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Concurrency101")
                .font(.system(size: DemoLayout.typeSize(34), weight: .regular, design: .serif))
                .foregroundStyle(DemoTheme.phosphor)
            Text("Two runtimes. Same questions — who is waiting, does this touch the UI, can this overlap. Pick a world, then Playground, Notes, or Drill. Amber is the main thread; cyan is everything else.")
                .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TrackDoor: View {
    let track: LearningTrack
    var compactVertical: Bool = false
    let action: () -> Void

    var body: some View {
        ChoiceCard(
            title: track.title,
            blurb: track.landingBlurb,
            cta: track.landingCTA,
            accent: track.accent,
            compactVertical: compactVertical,
            minHeight: compactVertical ? 160 : 280,
            action: action
        ) {
            TrackGlyph(track: track)
        }
    }
}
