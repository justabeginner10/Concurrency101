import Foundation
import Observation
import Concurrency101Sim

enum SandboxOutputTab: String, CaseIterable, Identifiable {
    case trace = "Trace"
    case threads = "Threads"

    var id: String { rawValue }
}

/// How fast virtual time plays back on screen.
enum SandboxSpeed: String, CaseIterable, Identifiable {
    case realTime = "1×"
    case slow = "¼×"
    case instant = "Instant"

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .realTime: return 1
        case .slow: return 0.25
        case .instant: return .infinity
        }
    }
}

/// One Sandbox: the learner's code, live diagnostics, and the latest
/// simulated run being played back over virtual time.
@MainActor
@Observable
final class SandboxSession {
    let track: LearningTrack

    var source: String {
        didSet {
            guard source != oldValue else { return }
            scheduleCheck()
            LearningMemory.saveSandboxDraft(track: track, source: source)
        }
    }

    private(set) var diagnostics: [SimDiagnostic] = []
    private(set) var run: SimRun?
    private(set) var isRunning = false
    private(set) var playhead: Double = 0
    private(set) var isPlaybackDone = true
    private(set) var loadedTitle: String?

    var speed: SandboxSpeed = .realTime
    var cores = 4
    private(set) var seed: UInt64 = 1
    var tab: SandboxOutputTab = .trace

    private var playbackTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?
    /// The code as last loaded, to tell whether the learner has edited it.
    private var loadedSource: String?
    private var started = false

    /// Cheap and side-effect free: SwiftUI may build this more than once
    /// before it keeps one. `start()` does the rest.
    init(track: LearningTrack, initialLessonID: String?, useAppleSnippet: Bool) {
        self.track = track
        let scenarios = ScenarioLibrary.scenarios(for: track)
        if let id = initialLessonID, let scenario = scenarios.first(where: { $0.id == id }) {
            source = useAppleSnippet ? scenario.appleSnippet : scenario.teachingSnippet
            loadedTitle = scenario.title
            loadedSource = source
        } else if let draft = LearningMemory.sandboxDraft(track: track), !draft.isEmpty {
            source = draft
        } else {
            source = scenarios.first?.teachingSnippet ?? ""
            loadedTitle = scenarios.first?.title
            loadedSource = source
        }
    }

    func start() {
        guard !started else { return }
        started = true
        LearningMemory.saveSandboxDraft(track: track, source: source)
        scheduleCheck(after: .zero)
    }

    /// True when loading something else would throw away the learner's work.
    var hasUnsavedEdits: Bool {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && source != loadedSource
    }

    var scenarios: [DemoScenario] {
        ScenarioLibrary.scenarios(for: track)
    }

    var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    /// Events whose virtual time the playback has reached.
    var visibleEvents: [SimEvent] {
        guard let run else { return [] }
        if isPlaybackDone { return run.events }
        return run.events.filter { $0.time <= playhead }
    }

    func load(_ scenario: DemoScenario, apple: Bool) {
        stopPlayback()
        run = nil
        source = apple ? scenario.appleSnippet : scenario.teachingSnippet
        loadedSource = source
        loadedTitle = scenario.title
    }

    func clearCode() {
        stopPlayback()
        run = nil
        source = ""
        loadedSource = ""
        loadedTitle = nil
    }

    func runCode() {
        startRun()
    }

    /// Same code, a different valid interleaving.
    func shuffle() {
        seed &+= 1
        startRun()
    }

    func skipToEnd() {
        guard let run else { return }
        stopPlayback()
        playhead = run.endTime
        isPlaybackDone = true
    }

    private func startRun() {
        stopPlayback()
        isRunning = true
        let code = source
        let configuration = SimConfiguration(cores: cores, seed: seed)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Simulator.run(code, configuration: configuration)
            }.value
            isRunning = false
            run = result
            diagnostics = result.diagnostics
            if result.outcome == .compileFailed {
                playhead = 0
                isPlaybackDone = true
                return
            }
            play(result)
        }
    }

    private func play(_ result: SimRun) {
        playhead = 0
        isPlaybackDone = false
        if speed == .instant || result.endTime <= 0 {
            playhead = result.endTime
            isPlaybackDone = true
            return
        }
        let factor = speed.factor
        playbackTask = Task { [weak self] in
            let start = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start) * factor
                guard let self else { return }
                self.playhead = min(elapsed, result.endTime)
                if elapsed >= result.endTime { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard let self, !Task.isCancelled else { return }
            self.playhead = result.endTime
            self.isPlaybackDone = true
        }
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaybackDone = true
    }

    private func scheduleCheck(after delay: Duration = .milliseconds(350)) {
        checkTask?.cancel()
        let code = source
        checkTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .utility) {
                Simulator.check(code)
            }.value
            guard !Task.isCancelled, let self, self.source == code else { return }
            self.diagnostics = found
        }
    }
}
