import SwiftUI

struct WorkbenchView: View {
    let track: LearningTrack

    @StateObject private var log = DemoLog()
    @State private var selectedID = ""
    @State private var consoleExpanded = false
    @State private var confirmDeadlock = false
    @State private var showCheatSheet = false
    @State private var showAppleAPI = false

    private var scenarios: [DemoScenario] {
        switch track {
        case .gcd: return GCDScenarioLibrary.all
        case .modern: return ModernScenarioLibrary.all
        }
    }

    private var selected: DemoScenario {
        scenarios.first { $0.id == selectedID } ?? scenarios[0]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DemoTheme.void.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                WorkbenchHeader(
                    trackTitle: track.shortTitle,
                    showCheatSheet: $showCheatSheet
                )
                LessonStrip(
                    scenarios: scenarios,
                    selectedID: selectedID,
                    onSelect: { selectedID = $0 }
                )
                ScrollView {
                    LessonBody(
                        scenario: selected,
                        appleLabel: track.appleLabel,
                        showAppleAPI: $showAppleAPI,
                        onRun: {
                            if selected.isDestructive {
                                confirmDeadlock = true
                            } else {
                                selected.run(log)
                            }
                        }
                    )
                }
                .padding(.bottom, consoleExpanded ? 348 : 176)
            }
            .padding(.bottom, 8)

            ConsoleOverlay(log: log, expanded: $consoleExpanded)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .onAppear {
            if selectedID.isEmpty {
                selectedID = scenarios[0].id
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(DemoTheme.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .alert("This freezes the app", isPresented: $confirmDeadlock) {
            Button("Freeze", role: .destructive) {
                selected.run(log)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deadlockMessage)
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView(track: track)
        }
    }

    private var deadlockMessage: String {
        switch track {
        case .gcd:
            return "main.sync from the main thread never returns. Stop the run in Xcode or force-quit."
        case .modern:
            return "Parking the main thread while waiting for MainActor work never returns. Stop the run in Xcode or force-quit."
        }
    }
}

private struct WorkbenchHeader: View {
    let trackTitle: String
    @Binding var showCheatSheet: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trackTitle)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(DemoTheme.phosphor)
                Text("Workbench. Amber is the main thread; cyan is everything else. Xcode prints the same lines.")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(DemoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                showCheatSheet = true
            } label: {
                Text("Cheat sheet")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DemoTheme.void)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DemoTheme.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

private struct LessonStrip: View {
    let scenarios: [DemoScenario]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scenarios) { scenario in
                    Button {
                        onSelect(scenario.id)
                    } label: {
                        Text(scenario.title)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(selectedID == scenario.id ? DemoTheme.void : DemoTheme.phosphor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedID == scenario.id ? DemoTheme.phosphor : Color.white.opacity(0.06))
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
        .padding(.bottom, 16)
    }
}

private struct LessonBody: View {
    let scenario: DemoScenario
    let appleLabel: String
    @Binding var showAppleAPI: Bool
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scenario.appleAPI)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DemoTheme.cyan)
            Text(scenario.blurb)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            CodeSnippetView(
                teachingSnippet: scenario.teachingSnippet,
                appleSnippet: scenario.appleSnippet,
                appleLabel: appleLabel,
                showAppleAPI: $showAppleAPI
            )

            Button(action: onRun) {
                Text(scenario.isDestructive ? "Run (will freeze)" : "Run lesson")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(scenario.isDestructive ? DemoTheme.freeze : DemoTheme.phosphor)
                    .foregroundStyle(DemoTheme.void)
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(.horizontal, 16)
    }
}
