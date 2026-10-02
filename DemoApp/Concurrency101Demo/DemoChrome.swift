import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DemoLayout {
    static var isPadLike: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
        #else
        true
        #endif
    }

    /// Stacked phone chrome is portrait iPhone only.
    /// Landscape iPhone, iPad, and Mac get the wide rooms.
    static func usesPhoneChrome(verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass != .compact
        #else
        false
        #endif
    }

    static func sidebarWidth(verticalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        verticalSizeClass == .compact ? 240 : 320
    }

    /// Two extra points on iPad/Mac so copy is easier to read at tablet distance.
    static func typeSize(_ phone: CGFloat) -> CGFloat {
        isPadLike ? phone + 2 : phone
    }
}

private enum UsesPhoneChromeKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }()
}

extension EnvironmentValues {
    var usesPhoneChrome: Bool {
        get { self[UsesPhoneChromeKey.self] }
        set { self[UsesPhoneChromeKey.self] = newValue }
    }
}

enum DemoSourceType {
    static let storageKey = "demo.sourceFontSize"
    static let sizes = [10, 11, 12, 13, 14, 16, 18, 20, 24]
    static var defaultSize: Int { Int(DemoLayout.typeSize(12)) }

    static func gutterWidth(fontSize: CGFloat, lineCount: Int) -> CGFloat {
        lineCount >= 100 ? max(28, fontSize + 14) : max(22, fontSize + 10)
    }
}

struct WorkbenchOptionsMenu: View {
    @Binding var showCheatSheet: Bool
    let accent: Color
    @AppStorage(DemoSourceType.storageKey) private var size = DemoSourceType.defaultSize

    var body: some View {
        Menu {
            Button {
                showCheatSheet = true
            } label: {
                Label("Cheat sheet", systemImage: "text.book.closed")
            }
            Menu {
                Picker("Font size", selection: $size) {
                    ForEach(DemoSourceType.sizes, id: \.self) { points in
                        Text(verbatim: "\(points) pt").tag(points)
                    }
                }
            } label: {
                Label("Font size", systemImage: "textformat.size")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel("Playground options")
    }
}

enum PathRoom: String, Hashable, Identifiable {
    case playground
    case notes
    case drill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playground: return "Playground"
        case .notes: return "Notes"
        case .drill: return "Drill"
        }
    }

    func blurb(noteCount: Int) -> String {
        switch self {
        case .playground:
            return "Run the lessons. Watch work land on the glass console — the same lines Xcode prints."
        case .notes:
            return "The Obsidian curriculum for this path, \(noteCount) notes, with a sidebar to move between them."
        case .drill:
            return "Closed-book quizzes for this path. The quiz flow is next; playground and notes are ready now."
        }
    }

    var cta: String {
        switch self {
        case .playground: return "Open Playground"
        case .notes: return "Open Notes"
        case .drill: return "Coming next"
        }
    }
}

extension LearningTrack {
    var accent: Color {
        self == .gcd ? DemoTheme.phosphor : DemoTheme.cyan
    }

    var hubNavigationTitle: String {
        switch self {
        case .gcd: return "GCD"
        case .modern: return "Swift Concurrency"
        }
    }
}

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
