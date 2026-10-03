import SwiftUI

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

    var hubNavigationTitle: String {
        switch self {
        case .gcd: return "GCD"
        case .modern: return "Swift Concurrency"
        }
    }

    var accent: Color {
        self == .gcd ? DemoTheme.phosphor : DemoTheme.cyan
    }

    var landingBlurb: String {
        switch self {
        case .gcd:
            return "Queues, QoS, barriers, groups, and the kind of sync that parks a thread. Intent names map 1:1 onto Dispatch."
        case .modern:
            return "Tasks, actors, await, isolation, and cooperative cancel. Intent names map 1:1 onto Swift Concurrency."
        }
    }

    var landingCTA: String {
        switch self {
        case .gcd: return "Open GCD"
        case .modern: return "Open Swift Concurrency"
        }
    }

    var playgroundDeadlockMessage: String {
        switch self {
        case .gcd:
            return "main.sync from the main thread never returns. Stop the run in Xcode or force-quit."
        case .modern:
            return "Parking the main thread while waiting for MainActor work never returns. Stop the run in Xcode or force-quit."
        }
    }

    var cheatSheetTitle: String {
        switch self {
        case .gcd: return "GCD cheat sheet"
        case .modern: return "Swift cheat sheet"
        }
    }
}
