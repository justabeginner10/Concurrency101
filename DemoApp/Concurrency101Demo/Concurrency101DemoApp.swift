import SwiftUI

@main
struct Concurrency101DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

enum LearningTrack: String, Identifiable, Hashable {
    case gcd
    case modern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gcd: return "Grand Central Dispatch"
        case .modern: return "Swift Concurrency"
        }
    }

    var shortTitle: String {
        switch self {
        case .gcd: return "GCD"
        case .modern: return "Swift"
        }
    }

    var appleLabel: String {
        switch self {
        case .gcd: return "Apple GCD"
        case .modern: return "Apple Swift"
        }
    }
}

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
