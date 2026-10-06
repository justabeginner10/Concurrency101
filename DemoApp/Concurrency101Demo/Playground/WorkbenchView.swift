import SwiftUI

struct WorkbenchView: View {
    let track: LearningTrack

    @State private var log = DemoLog()
    @State private var selectedID: String
    @State private var consoleExpanded = false
    @State private var confirmDeadlock = false
    @State private var showCheatSheet = false
    @State private var showAppleAPI = false
    @State private var maximizedPanel: WorkbenchPanel?
    @State private var predictionChoice: Int?
    @State private var predictionOrder: [Int]
    @State private var predictionRan = false
    @State private var loggedPredictionChoice: Int?
    @Environment(\.usesPhoneChrome) private var usesPhoneChrome

    init(track: LearningTrack, initialLessonID: String? = nil) {
        self.track = track
        let scenarios = ScenarioLibrary.scenarios(for: track)
        let preferred = initialLessonID ?? LearningMemory.lastLessonID(track: track)
        let start = scenarios.first { $0.id == preferred }?.id ?? scenarios.first?.id ?? ""
        _selectedID = State(initialValue: start)
        _predictionOrder = State(initialValue: [0, 1].shuffled())
    }

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
                    onSelect: selectLesson,
                    onRun: runSelected,
                    canRun: canRun,
                    prediction: selected.prediction,
                    predictionOrder: predictionOrder,
                    predictionChoice: predictionChoice,
                    predictionRan: predictionRan,
                    onPickPrediction: pickPrediction,
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
                    onSelect: selectLesson,
                    onRun: runSelected,
                    canRun: canRun,
                    prediction: selected.prediction,
                    predictionOrder: predictionOrder,
                    predictionChoice: predictionChoice,
                    predictionRan: predictionRan,
                    onPickPrediction: pickPrediction,
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
            rememberLesson()
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
                performRun()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(track.playgroundDeadlockMessage)
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView(track: track)
        }
    }

    private var canRun: Bool {
        selected.prediction == nil || predictionChoice != nil
    }

    private func selectLesson(_ id: String) {
        guard id != selectedID else { return }
        selectedID = id
        predictionChoice = nil
        predictionRan = false
        loggedPredictionChoice = nil
        predictionOrder = [0, 1].shuffled()
        log = DemoLog()
        rememberLesson()
    }

    private func pickPrediction(_ index: Int) {
        guard !predictionRan else { return }
        predictionChoice = index
    }

    private func rememberLesson() {
        guard let match = scenarios.first(where: { $0.id == selectedID }) else { return }
        LearningMemory.rememberLesson(track: track, id: match.id, title: match.title)
    }

    private func runSelected() {
        guard canRun else { return }
        recordPredictionIfNeeded()
        if selected.isDestructive {
            confirmDeadlock = true
        } else {
            performRun()
        }
    }

    private func performRun() {
        predictionRan = true
        LearningMemory.markLessonRun(track: track, id: selected.id)
        selected.run(log)
    }

    private func recordPredictionIfNeeded() {
        guard let prediction = selected.prediction, let predictionChoice else { return }
        guard predictionChoice != prediction.correctIndex else { return }
        guard loggedPredictionChoice != predictionChoice else { return }
        loggedPredictionChoice = predictionChoice
        LearningMemory.appendMiss(
            track: track,
            miss: LearningMiss(
                id: UUID(),
                date: Date(),
                module: selected.title,
                predicted: prediction.choices[predictionChoice],
                actual: prediction.choices[prediction.correctIndex],
                why: selected.blurb
            )
        )
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
    let canRun: Bool
    let prediction: LessonPrediction?
    let predictionOrder: [Int]
    let predictionChoice: Int?
    let predictionRan: Bool
    let onPickPrediction: (Int) -> Void
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
                    canRun: canRun,
                    onSelect: onSelect,
                    onRun: onRun
                )
                ScrollView {
                    LessonBody(
                        scenario: selected,
                        appleLabel: appleLabel,
                        appleChip: appleChip,
                        accent: accent,
                        showAppleAPI: $showAppleAPI,
                        prediction: prediction,
                        predictionOrder: predictionOrder,
                        predictionChoice: predictionChoice,
                        predictionRan: predictionRan,
                        onPickPrediction: onPickPrediction,
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
    let canRun: Bool
    let prediction: LessonPrediction?
    let predictionOrder: [Int]
    let predictionChoice: Int?
    let predictionRan: Bool
    let onPickPrediction: (Int) -> Void
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
                canRun: canRun,
                onSelect: onSelect,
                onRun: onRun
            )
            LessonCopy(
                appleAPI: selected.appleAPI,
                blurb: selected.blurb,
                compact: compactVertical
            )
            .padding(.horizontal, 16)
            .padding(.bottom, compactVertical ? 4 : 8)
            if let prediction {
                LessonPredictionBox(
                    prediction: prediction,
                    order: predictionOrder,
                    choice: predictionChoice,
                    ran: predictionRan,
                    accent: accent,
                    onPick: onPickPrediction
                )
                .padding(.horizontal, 16)
                .padding(.bottom, compactVertical ? 8 : 12)
            }
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
    let canRun: Bool
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
                isEnabled: canRun,
                fillsWidth: false,
                minWidth: DemoLayout.isPadLike ? 168 : 0,
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
    var isEnabled: Bool = true
    var fillsWidth: Bool = true
    var minWidth: CGFloat = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isDestructive ? "Run (will freeze)" : "Run lesson")
                .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                .padding(.horizontal, fillsWidth ? 16 : 14)
                .padding(.vertical, fillsWidth ? 12 : 8)
                .frame(minWidth: fillsWidth ? 0 : minWidth, maxWidth: fillsWidth ? .infinity : nil)
                .background(fill)
                .foregroundStyle(isEnabled ? DemoTheme.void : DemoTheme.muted)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .layoutPriority(fillsWidth ? 0 : 1)
        .disabled(!isEnabled)
        .accessibilityHint(isEnabled ? "Runs the lesson" : "Choose a prediction first")
    }

    private var fill: Color {
        guard isEnabled else { return Color.white.opacity(0.08) }
        return isDestructive ? DemoTheme.freeze : DemoTheme.phosphor
    }
}

private struct LessonBody: View {
    let scenario: DemoScenario
    let appleLabel: String
    let appleChip: String
    var accent: Color = DemoTheme.phosphor
    @Binding var showAppleAPI: Bool
    var prediction: LessonPrediction? = nil
    var predictionOrder: [Int] = [0, 1]
    var predictionChoice: Int? = nil
    var predictionRan: Bool = false
    var onPickPrediction: (Int) -> Void = { _ in }
    var onMaximizeCode: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LessonCopy(appleAPI: scenario.appleAPI, blurb: scenario.blurb)
            if let prediction {
                LessonPredictionBox(
                    prediction: prediction,
                    order: predictionOrder,
                    choice: predictionChoice,
                    ran: predictionRan,
                    accent: accent,
                    onPick: onPickPrediction
                )
            }
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

private struct LessonPredictionBox: View {
    let prediction: LessonPrediction
    let order: [Int]
    let choice: Int?
    let ran: Bool
    let accent: Color
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Predict, then run")
                .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                .foregroundStyle(DemoTheme.muted)
            Text(verbatim: prediction.prompt)
                .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(order, id: \.self) { index in
                if prediction.choices.indices.contains(index) {
                    Button {
                        onPick(index)
                    } label: {
                        Text(verbatim: prediction.choices[index])
                            .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                            .foregroundStyle(labelColor(for: index))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(fill(for: index))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(border(for: index), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(ran)
                }
            }
            if ran, let choice, prediction.choices.indices.contains(choice) {
                Text(choice == prediction.correctIndex ? "That prediction hit." : "That prediction missed.")
                    .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                    .foregroundStyle(choice == prediction.correctIndex ? DemoTheme.hit : DemoTheme.freeze)
            }
        }
    }

    private func fill(for index: Int) -> Color {
        if ran, index == prediction.correctIndex { return DemoTheme.hit }
        if ran, choice == index { return DemoTheme.freeze }
        if choice == index { return accent.opacity(0.16) }
        return Color.white.opacity(0.04)
    }

    private func border(for index: Int) -> Color {
        if ran, index == prediction.correctIndex { return DemoTheme.hit }
        if ran, choice == index { return DemoTheme.freeze }
        if choice == index { return accent.opacity(0.7) }
        return Color.white.opacity(0.08)
    }

    private func labelColor(for index: Int) -> Color {
        let revealed = ran && (index == prediction.correctIndex || choice == index)
        return revealed ? DemoTheme.void : Color.white.opacity(0.88)
    }
}
