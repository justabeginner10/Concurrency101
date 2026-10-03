import SwiftUI

struct WorkbenchView: View {
    let track: LearningTrack

    @StateObject private var log = DemoLog()
    @State private var selectedID = ""
    @State private var consoleExpanded = false
    @State private var confirmDeadlock = false
    @State private var showCheatSheet = false
    @State private var showAppleAPI = false
    @Environment(\.usesPhoneChrome) private var usesPhoneChrome

    private var scenarios: [DemoScenario] {
        ScenarioLibrary.scenarios(for: track)
    }

    private var selected: DemoScenario {
        if let match = scenarios.first(where: { $0.id == selectedID }) {
            return match
        }
        guard let first = scenarios.first else {
            preconditionFailure("ScenarioLibrary has no lessons for \(track)")
        }
        return first
    }

    var body: some View {
        DemoCanvas {
            if usesPhoneChrome {
                PhoneWorkbenchLayout(
                    trackTitle: track.shortTitle,
                    appleLabel: track.appleLabel,
                    appleChip: track.shortTitle,
                    accent: track.accent,
                    scenarios: scenarios,
                    selected: selected,
                    selectedID: selectedID,
                    log: log,
                    consoleExpanded: $consoleExpanded,
                    showAppleAPI: $showAppleAPI,
                    onSelect: { selectedID = $0 },
                    onRun: runSelected
                )
            } else {
                PadWorkbenchLayout(
                    trackTitle: track.shortTitle,
                    appleLabel: track.appleLabel,
                    appleChip: track.shortTitle,
                    accent: track.accent,
                    scenarios: scenarios,
                    selected: selected,
                    selectedID: selectedID,
                    log: log,
                    showAppleAPI: $showAppleAPI,
                    onSelect: { selectedID = $0 },
                    onRun: runSelected
                )
            }
        }
        .onAppear {
            if selectedID.isEmpty, let first = scenarios.first {
                selectedID = first.id
            }
        }
        .navigationTitle("Playground")
        .demoRoomChrome()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                WorkbenchOptionsMenu(showCheatSheet: $showCheatSheet, accent: track.accent)
            }
        }
        .alert("This freezes the app", isPresented: $confirmDeadlock) {
            Button("Freeze", role: .destructive) {
                selected.run(log)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(track.playgroundDeadlockMessage)
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView(track: track)
        }
    }

    private func runSelected() {
        if selected.isDestructive {
            confirmDeadlock = true
        } else {
            selected.run(log)
        }
    }
}

private struct PhoneWorkbenchLayout: View {
    let trackTitle: String
    let appleLabel: String
    let appleChip: String
    let accent: Color
    let scenarios: [DemoScenario]
    let selected: DemoScenario
    let selectedID: String
    @ObservedObject var log: DemoLog
    @Binding var consoleExpanded: Bool
    @Binding var showAppleAPI: Bool
    let onSelect: (String) -> Void
    let onRun: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                WorkbenchHeader(trackTitle: trackTitle, accent: accent)
                LessonStrip(
                    scenarios: scenarios,
                    selectedID: selectedID,
                    accent: accent,
                    onSelect: onSelect
                )
                ScrollView {
                    LessonBody(
                        scenario: selected,
                        appleLabel: appleLabel,
                        appleChip: appleChip,
                        showAppleAPI: $showAppleAPI,
                        onRun: onRun
                    )
                }
                .padding(.bottom, consoleExpanded ? 348 : 176)
            }
            .padding(.bottom, 8)

            ConsoleOverlay(log: log, expanded: $consoleExpanded, chrome: .docked)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
    }
}

private struct PadWorkbenchLayout: View {
    let trackTitle: String
    let appleLabel: String
    let appleChip: String
    let accent: Color
    let scenarios: [DemoScenario]
    let selected: DemoScenario
    let selectedID: String
    @ObservedObject var log: DemoLog
    @Binding var showAppleAPI: Bool
    let onSelect: (String) -> Void
    let onRun: () -> Void
    @State private var consoleExpanded = true
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var compactVertical: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkbenchHeader(
                trackTitle: trackTitle,
                accent: accent,
                showsBlurb: !compactVertical
            )
            LessonStrip(
                scenarios: scenarios,
                selectedID: selectedID,
                accent: accent,
                onSelect: onSelect,
                compact: compactVertical
            )
            PadLessonIntro(
                compact: compactVertical,
                appleAPI: selected.appleAPI,
                blurb: selected.blurb,
                isDestructive: selected.isDestructive,
                onRun: onRun
            )
            HStack(alignment: .top, spacing: 12) {
                CodeSnippetView(
                    teachingSnippet: selected.teachingSnippet,
                    appleSnippet: selected.appleSnippet,
                    appleLabel: appleLabel,
                    appleChip: appleChip,
                    showAppleAPI: $showAppleAPI,
                    fillsAvailableHeight: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                ConsoleOverlay(log: log, expanded: $consoleExpanded, chrome: .pane)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, compactVertical ? 8 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct PadLessonIntro: View {
    let compact: Bool
    let appleAPI: String
    let blurb: String
    let isDestructive: Bool
    let onRun: () -> Void

    var body: some View {
        if compact {
            HStack(alignment: .center, spacing: 12) {
                LessonCopy(appleAPI: appleAPI, blurb: blurb, compact: true)
                RunLessonButton(isDestructive: isDestructive, action: onRun)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                LessonCopy(appleAPI: appleAPI, blurb: blurb)
                    .padding(.horizontal, 16)
                RunLessonButton(isDestructive: isDestructive, action: onRun)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }
}

private struct WorkbenchHeader: View {
    let trackTitle: String
    let accent: Color
    var showsBlurb: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trackTitle)
                .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                .foregroundStyle(accent)
            if showsBlurb {
                Text("Workbench. Amber is the main thread; cyan is everything else. Xcode prints the same lines.")
                    .font(.system(size: DemoLayout.typeSize(13), design: .serif))
                    .foregroundStyle(DemoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, showsBlurb ? 8 : 4)
        .padding(.bottom, showsBlurb ? 12 : 8)
    }
}

private struct LessonStrip: View {
    let scenarios: [DemoScenario]
    let selectedID: String
    let accent: Color
    let onSelect: (String) -> Void
    var compact: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scenarios) { scenario in
                    Button {
                        onSelect(scenario.id)
                    } label: {
                        Text(scenario.title)
                            .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                            .foregroundStyle(selectedID == scenario.id ? DemoTheme.void : accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedID == scenario.id ? accent : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        scenario.isDestructive ? DemoTheme.freeze.opacity(0.8) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, compact ? 8 : 16)
    }
}

private struct LessonCopy: View {
    let appleAPI: String
    let blurb: String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 12) {
            Text(appleAPI)
                .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                .foregroundStyle(DemoTheme.cyan)
                .lineLimit(compact ? 1 : nil)
            Text(blurb)
                .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(compact ? 2 : nil)
                .fixedSize(horizontal: false, vertical: !compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RunLessonButton: View {
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isDestructive ? "Run (will freeze)" : "Run lesson")
                .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isDestructive ? DemoTheme.freeze : DemoTheme.phosphor)
                .foregroundStyle(DemoTheme.void)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct LessonBody: View {
    let scenario: DemoScenario
    let appleLabel: String
    let appleChip: String
    @Binding var showAppleAPI: Bool
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LessonCopy(appleAPI: scenario.appleAPI, blurb: scenario.blurb)
            CodeSnippetView(
                teachingSnippet: scenario.teachingSnippet,
                appleSnippet: scenario.appleSnippet,
                appleLabel: appleLabel,
                appleChip: appleChip,
                showAppleAPI: $showAppleAPI
            )
            RunLessonButton(isDestructive: scenario.isDestructive, action: onRun)
        }
        .padding(.horizontal, 16)
    }
}
