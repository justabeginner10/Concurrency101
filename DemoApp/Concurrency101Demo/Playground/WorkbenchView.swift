import SwiftUI

struct WorkbenchView: View {
    let track: LearningTrack

    @State private var log = DemoLog()
    @State private var selectedID = ""
    @State private var consoleExpanded = false
    @State private var confirmDeadlock = false
    @State private var showCheatSheet = false
    @State private var showAppleAPI = false
    @State private var maximizedPanel: WorkbenchPanel?
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
                    onRun: runSelected,
                    onMaximizeCode: { maximize(.code) },
                    onMaximizeConsole: { maximize(.console) }
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
                    onRun: runSelected,
                    onMaximizeCode: { maximize(.code) },
                    onMaximizeConsole: { maximize(.console) }
                )
            }
        }
        .overlay {
            if let maximizedPanel {
                WorkbenchMaximizeOverlay(
                    panel: maximizedPanel,
                    teachingSnippet: selected.teachingSnippet,
                    appleSnippet: selected.appleSnippet,
                    appleLabel: track.appleLabel,
                    appleChip: track.shortTitle,
                    showAppleAPI: $showAppleAPI,
                    log: log,
                    consoleExpanded: $consoleExpanded,
                    onMinimize: minimize
                )
                .transition(.opacity)
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

    private func maximize(_ panel: WorkbenchPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            maximizedPanel = panel
        }
    }

    private func minimize() {
        withAnimation(.easeInOut(duration: 0.2)) {
            maximizedPanel = nil
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
    let log: DemoLog
    @Binding var consoleExpanded: Bool
    @Binding var showAppleAPI: Bool
    let onSelect: (String) -> Void
    let onRun: () -> Void
    let onMaximizeCode: () -> Void
    let onMaximizeConsole: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                WorkbenchHeader(trackTitle: trackTitle, accent: accent)
                PlaygroundLessonChrome(
                    scenarios: scenarios,
                    selectedID: selectedID,
                    selectedTitle: selected.title,
                    accent: accent,
                    isDestructive: selected.isDestructive,
                    onSelect: onSelect,
                    onRun: onRun
                )
                ScrollView {
                    LessonBody(
                        scenario: selected,
                        appleLabel: appleLabel,
                        appleChip: appleChip,
                        showAppleAPI: $showAppleAPI,
                        onMaximizeCode: onMaximizeCode
                    )
                }
                .padding(.bottom, consoleExpanded ? 348 : 176)
            }
            .padding(.bottom, 8)

            ConsoleOverlay(
                log: log,
                expanded: $consoleExpanded,
                chrome: .docked,
                onToggleMaximize: onMaximizeConsole
            )
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
    let log: DemoLog
    @Binding var showAppleAPI: Bool
    let onSelect: (String) -> Void
    let onRun: () -> Void
    let onMaximizeCode: () -> Void
    let onMaximizeConsole: () -> Void
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
            PlaygroundLessonChrome(
                scenarios: scenarios,
                selectedID: selectedID,
                selectedTitle: selected.title,
                accent: accent,
                isDestructive: selected.isDestructive,
                onSelect: onSelect,
                onRun: onRun
            )
            LessonCopy(
                appleAPI: selected.appleAPI,
                blurb: selected.blurb,
                compact: compactVertical
            )
            .padding(.horizontal, 16)
            .padding(.bottom, compactVertical ? 8 : 12)
            HStack(alignment: .top, spacing: 12) {
                CodeSnippetView(
                    teachingSnippet: selected.teachingSnippet,
                    appleSnippet: selected.appleSnippet,
                    appleLabel: appleLabel,
                    appleChip: appleChip,
                    showAppleAPI: $showAppleAPI,
                    fillsAvailableHeight: true,
                    onToggleMaximize: onMaximizeCode
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                ConsoleOverlay(
                    log: log,
                    expanded: $consoleExpanded,
                    chrome: .pane,
                    onToggleMaximize: onMaximizeConsole
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, compactVertical ? 8 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct PlaygroundLessonChrome: View {
    let scenarios: [DemoScenario]
    let selectedID: String
    let selectedTitle: String
    let accent: Color
    let isDestructive: Bool
    let onSelect: (String) -> Void
    let onRun: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            LessonPickerMenu(
                scenarios: scenarios,
                selectedID: selectedID,
                selectedTitle: selectedTitle,
                accent: accent,
                isDestructive: isDestructive,
                onSelect: onSelect
            )
            .frame(minWidth: 0, maxWidth: .infinity)
            RunLessonButton(
                isDestructive: isDestructive,
                fillsWidth: false,
                action: onRun
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

private struct LessonPickerMenu: View {
    let scenarios: [DemoScenario]
    let selectedID: String
    let selectedTitle: String
    let accent: Color
    let isDestructive: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            Picker("Lesson", selection: Binding(
                get: { selectedID },
                set: onSelect
            )) {
                ForEach(scenarios) { scenario in
                    Text(scenario.title).tag(scenario.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedTitle)
                    .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        isDestructive ? DemoTheme.freeze.opacity(0.8) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .menuOrder(.fixed)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Lesson")
        .accessibilityValue(selectedTitle)
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
    var fillsWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isDestructive ? "Run (will freeze)" : "Run lesson")
                .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                .padding(.horizontal, fillsWidth ? 16 : 14)
                .padding(.vertical, fillsWidth ? 12 : 8)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .background(isDestructive ? DemoTheme.freeze : DemoTheme.phosphor)
                .foregroundStyle(DemoTheme.void)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .layoutPriority(fillsWidth ? 0 : 1)
    }
}

private struct LessonBody: View {
    let scenario: DemoScenario
    let appleLabel: String
    let appleChip: String
    @Binding var showAppleAPI: Bool
    var onMaximizeCode: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LessonCopy(appleAPI: scenario.appleAPI, blurb: scenario.blurb)
            CodeSnippetView(
                teachingSnippet: scenario.teachingSnippet,
                appleSnippet: scenario.appleSnippet,
                appleLabel: appleLabel,
                appleChip: appleChip,
                showAppleAPI: $showAppleAPI,
                onToggleMaximize: onMaximizeCode
            )
        }
        .padding(.horizontal, 16)
    }
}

private enum WorkbenchPanel {
    case code
    case console
}

private struct WorkbenchMaximizeOverlay: View {
    let panel: WorkbenchPanel
    let teachingSnippet: String
    let appleSnippet: String
    let appleLabel: String
    let appleChip: String
    @Binding var showAppleAPI: Bool
    let log: DemoLog
    @Binding var consoleExpanded: Bool
    let onMinimize: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onMinimize)
                    .accessibilityLabel("Dismiss maximized panel")
                    .accessibilityAddTraits(.isButton)

                Group {
                    switch panel {
                    case .code:
                        CodeSnippetView(
                            teachingSnippet: teachingSnippet,
                            appleSnippet: appleSnippet,
                            appleLabel: appleLabel,
                            appleChip: appleChip,
                            showAppleAPI: $showAppleAPI,
                            fillsAvailableHeight: true,
                            isMaximized: true,
                            onToggleMaximize: onMinimize
                        )
                    case .console:
                        ConsoleOverlay(
                            log: log,
                            expanded: $consoleExpanded,
                            chrome: .pane,
                            isMaximized: true,
                            onToggleMaximize: onMinimize
                        )
                    }
                }
                .frame(width: max(0, geo.size.width - 32), height: max(0, geo.size.height - 32))
                .background(DemoTheme.void)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: Color.black.opacity(0.45), radius: 24, y: 8)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
