import SwiftUI
import Concurrency101Sim

/// The Sandbox room: edit Swift, run it on the simulated runtime, read the
/// trace and the thread timeline. Nothing here touches the real main thread,
/// so the freeze lessons can be explored without freezing the app.
struct SandboxView: View {
    let track: LearningTrack

    @State private var session: SandboxSession
    @State private var showHelp = false
    @State private var pendingLoad: PendingLoad?
    @Environment(\.usesPhoneChrome) private var usesPhoneChrome

    private struct PendingLoad: Identifiable {
        let scenario: DemoScenario?
        let apple: Bool
        var id: String { (scenario?.id ?? "blank") + (apple ? ".apple" : ".101") }
    }

    init(track: LearningTrack, initialLessonID: String? = nil, useAppleSnippet: Bool = false) {
        self.track = track
        _session = State(initialValue: SandboxSession(track: track, initialLessonID: initialLessonID, useAppleSnippet: useAppleSnippet))
    }

    var body: some View {
        DemoCanvas {
            if usesPhoneChrome {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SandboxHeader(track: track)
                        controls
                        SandboxEditorPanel(session: session, accent: track.accent)
                            .frame(height: 300)
                        SandboxOutputPanel(session: session, accent: track.accent)
                            .frame(height: 460)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SandboxHeader(track: track)
                    controls
                    HStack(alignment: .top, spacing: 12) {
                        SandboxEditorPanel(session: session, accent: track.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        SandboxOutputPanel(session: session, accent: track.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .task { session.start() }
        .navigationTitle("")
        .demoRoomChrome()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(track.accent)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("How the Sandbox works")
            }
        }
        .sheet(isPresented: $showHelp) {
            SandboxHelpSheet(accent: track.accent)
        }
        .confirmationDialog(
            "Replace your code?",
            isPresented: Binding(get: { pendingLoad != nil }, set: { if !$0 { pendingLoad = nil } }),
            titleVisibility: .visible,
            presenting: pendingLoad
        ) { load in
            Button(load.scenario == nil ? "Clear the editor" : "Load \(load.scenario!.title)", role: .destructive) {
                apply(load)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The editor holds code you changed. Loading replaces it.")
        }
    }

    private var controls: some View {
        SandboxControls(
            session: session,
            accent: track.accent,
            onLoad: { scenario, apple in request(PendingLoad(scenario: scenario, apple: apple)) },
            onClear: { request(PendingLoad(scenario: nil, apple: false)) }
        )
    }

    private func request(_ load: PendingLoad) {
        if session.hasUnsavedEdits {
            pendingLoad = load
        } else {
            apply(load)
        }
    }

    private func apply(_ load: PendingLoad) {
        if let scenario = load.scenario {
            session.load(scenario, apple: load.apple)
        } else {
            session.clearCode()
        }
        pendingLoad = nil
    }
}

private struct SandboxHeader: View {
    let track: LearningTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(track.shortTitle) Sandbox")
                .font(.system(size: DemoLayout.typeSize(28), weight: .regular, design: .serif))
                .foregroundStyle(track.accent)
            Text("Your code runs on a simulated runtime: one main thread, a GCD pool, a Swift task pool, and a virtual clock. It models the real runtime; it is not the real runtime.")
                .font(.system(size: DemoLayout.typeSize(13), design: .serif))
                .foregroundStyle(DemoTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}

private struct SandboxControls: View {
    let session: SandboxSession
    let accent: Color
    let onLoad: (DemoScenario, Bool) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Menu("Concurrency101 names") {
                        ForEach(session.scenarios) { scenario in
                            Button(scenario.title) { onLoad(scenario, false) }
                        }
                    }
                    Menu("Apple API") {
                        ForEach(session.scenarios) { scenario in
                            Button(scenario.title) { onLoad(scenario, true) }
                        }
                    }
                    Divider()
                    Button("Blank editor", role: .destructive, action: onClear)
                } label: {
                    HStack(spacing: 8) {
                        Text(verbatim: session.loadedTitle.map { "From: \($0)" } ?? "Your code")
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
                    .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .menuOrder(.fixed)
                .accessibilityLabel("Start from a lesson")

                Button(action: session.runCode) {
                    Text(session.isRunning ? "Running…" : "Run")
                        .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .frame(minWidth: DemoLayout.isPadLike ? 120 : 76)
                        .background(session.isRunning ? Color.white.opacity(0.08) : accent)
                        .foregroundStyle(session.isRunning ? DemoTheme.muted : DemoTheme.void)
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .disabled(session.isRunning)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityHint("Runs the code on the simulated runtime")
            }

            HStack(spacing: 14) {
                Button {
                    session.shuffle()
                } label: {
                    Label("Shuffle · seed \(session.seed)", systemImage: "shuffle")
                }
                .disabled(session.isRunning)
                .accessibilityHint("Runs again with another valid interleaving")

                Menu {
                    Picker("Cores", selection: Binding(get: { session.cores }, set: { session.cores = $0 })) {
                        ForEach([1, 2, 4, 8], id: \.self) { n in
                            Text("\(n) \(n == 1 ? "core" : "cores")").tag(n)
                        }
                    }
                } label: {
                    Label("\(session.cores) cores", systemImage: "cpu")
                }
                .menuIndicator(.hidden)

                Menu {
                    Picker("Speed", selection: Binding(get: { session.speed }, set: { session.speed = $0 })) {
                        ForEach(SandboxSpeed.allCases) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                } label: {
                    Label(session.speed.rawValue, systemImage: "speedometer")
                }
                .menuIndicator(.hidden)

                Spacer(minLength: 0)

                if !session.isPlaybackDone {
                    Button("Skip to end", action: session.skipToEnd)
                }
            }
            .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
            .buttonStyle(.plain)
            .foregroundStyle(DemoTheme.cyan)
            .labelStyle(.titleAndIcon)
        }
    }
}
