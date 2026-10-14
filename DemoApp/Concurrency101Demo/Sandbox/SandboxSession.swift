import Foundation
import Observation
import Concurrency101Sim

struct SandboxDraftSnapshot: Codable {
    let source: String
    let lessonID: String?
    let showAppleAPI: Bool
    let teachingSource: String?
    let appleSource: String?
}

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
            saveDraft()
        }
    }

    private(set) var diagnostics: [SimDiagnostic] = []
    private(set) var run: SimRun?
    private(set) var isRunning = false
    private(set) var playhead: Double = 0
    private(set) var isPlaybackDone = true
    private(set) var loadedTitle: String?
    private(set) var loadedScenario: DemoScenario?
    private var usesAppleSnippet = false
    private var teachingDraft: String?
    private var appleDraft: String?

    var canSwitchVersions: Bool { loadedScenario != nil }

    var showAppleAPI: Bool {
        get { usesAppleSnippet }
        set { switchVersion(apple: newValue) }
    }

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
            loadedScenario = scenario
            usesAppleSnippet = useAppleSnippet
            loadedTitle = scenario.title
            loadedSource = source
        } else if let draft = LearningMemory.sandboxDraftSnapshot(track: track) {
            source = draft.source
            if let scenario = scenarios.first(where: { $0.id == draft.lessonID }) {
                loadedScenario = scenario
                loadedTitle = scenario.title
                usesAppleSnippet = draft.showAppleAPI
                teachingDraft = draft.teachingSource
                appleDraft = draft.appleSource
                loadedSource = draft.showAppleAPI ? scenario.appleSnippet : scenario.teachingSnippet
            }
        } else if let draft = LearningMemory.sandboxDraft(track: track), !draft.isEmpty {
            source = draft
            if let scenario = scenarios.first(where: { $0.teachingSnippet == draft || $0.appleSnippet == draft }) {
                loadedScenario = scenario
                loadedTitle = scenario.title
                usesAppleSnippet = scenario.appleSnippet == draft
                loadedSource = draft
            }
        } else {
            source = scenarios.first?.teachingSnippet ?? ""
            loadedScenario = scenarios.first
            loadedTitle = scenarios.first?.title
            loadedSource = source
        }
    }

    func start() {
        guard !started else { return }
        started = true
        saveDraft()
        scheduleCheck(after: .zero)
    }

    /// True when loading something else would throw away the learner's work.
    var hasUnsavedEdits: Bool {
        if let scenario = loadedScenario {
            let teaching = usesAppleSnippet ? teachingDraft : source
            let apple = usesAppleSnippet ? source : appleDraft
            return Self.isEdited(teaching, original: scenario.teachingSnippet)
                || Self.isEdited(apple, original: scenario.appleSnippet)
        }
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
        loadedScenario = scenario
        usesAppleSnippet = apple
        teachingDraft = nil
        appleDraft = nil
        loadedSource = apple ? scenario.appleSnippet : scenario.teachingSnippet
        loadedTitle = scenario.title
        source = loadedSource ?? ""
        saveDraft()
    }

    func clearCode() {
        stopPlayback()
        run = nil
        loadedScenario = nil
        usesAppleSnippet = false
        teachingDraft = nil
        appleDraft = nil
        loadedSource = ""
        loadedTitle = nil
        source = ""
        saveDraft()
    }

    private func switchVersion(apple: Bool) {
        guard let scenario = loadedScenario, apple != usesAppleSnippet, !isRunning else { return }
        if usesAppleSnippet { appleDraft = source } else { teachingDraft = source }
        stopPlayback()
        run = nil
        usesAppleSnippet = apple
        loadedSource = apple ? scenario.appleSnippet : scenario.teachingSnippet
        source = apple ? (appleDraft ?? scenario.appleSnippet) : (teachingDraft ?? scenario.teachingSnippet)
        saveDraft()
    }

    private static func isEdited(_ draft: String?, original: String) -> Bool {
        guard let draft, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return draft != original
    }

    private func saveDraft() {
        LearningMemory.saveSandboxDraftSnapshot(track: track, snapshot: SandboxDraftSnapshot(
            source: source,
            lessonID: loadedScenario?.id,
            showAppleAPI: usesAppleSnippet,
            teachingSource: usesAppleSnippet ? teachingDraft : source,
            appleSource: usesAppleSnippet ? source : appleDraft
        ))
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
