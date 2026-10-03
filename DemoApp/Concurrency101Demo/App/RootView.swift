import SwiftUI

struct RootView: View {
    @State private var track: LearningTrack?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            LandingView(track: $track)
                .navigationDestination(item: $track) { selected in
                    TrackHubView(track: selected)
                }
        }
        .preferredColorScheme(.dark)
        .environment(
            \.usesPhoneChrome,
            DemoLayout.usesPhoneChrome(verticalSizeClass: verticalSizeClass)
        )
    }
}
