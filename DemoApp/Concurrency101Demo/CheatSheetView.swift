import SwiftUI

struct CheatSheetRow: Identifiable {
    let id: String
    let intent: String
    let teaching: String
    let apple: String
}

enum GCDCheatSheet {
    static let mappings: [CheatSheetRow] = [
        .init(id: "ui", intent: "Change the UI, do not wait", teaching: "GCD.updateUI { }", apple: "DispatchQueue.main.async"),
        .init(id: "ui-after", intent: "Change the UI after a delay", teaching: "GCD.updateUI(after:) { }", apple: "main.asyncAfter(deadline:)"),
        .init(id: "interactive", intent: "UI needs this now (tiny, rare)", teaching: "GCD.runForImmediateUI { }", apple: "global(qos: .userInteractive).async"),
        .init(id: "initiated", intent: "User tapped and is waiting", teaching: "GCD.runUserRequestedWork { }", apple: "global(qos: .userInitiated).async"),
        .init(id: "utility", intent: "Progress the user may watch", teaching: "GCD.runMaintenanceWork { }", apple: "global(qos: .utility).async"),
        .init(id: "background", intent: "User is not waiting", teaching: "GCD.runWhenUserIsNotWaiting { }", apple: "global(qos: .background).async"),
        .init(id: "serial", intent: "One-at-a-time private lane", teaching: "GCD.makePrivateSerialLane", apple: "DispatchQueue(label:) serial"),
        .init(id: "concurrent", intent: "Overlapping private lane", teaching: "GCD.makeSharedConcurrentLane", apple: "DispatchQueue(..., .concurrent)"),
        .init(id: "run-lane", intent: "Submit, do not wait", teaching: "GCD.runOnLane", apple: "queue.async"),
        .init(id: "barrier", intent: "Exclusive write among reads", teaching: "GCD.runExclusiveWrite", apple: "async(flags: .barrier)"),
        .init(id: "group", intent: "Several jobs, then continue", teaching: "GCD.runSeveralThenContinue", apple: "DispatchGroup.notify"),
        .init(id: "counter", intent: "Count callback completions", teaching: "GCD.CompletionCounter", apple: "enter / leave / notify"),
        .init(id: "work", intent: "Cooperative cancel", teaching: "GCD.makeCancellableWork", apple: "DispatchWorkItem"),
        .init(id: "sync", intent: "Block this thread (avoid)", teaching: "GCD.Blocking.blockThisThreadUntilFinished", apple: "queue.sync"),
        .init(id: "wait", intent: "Block for a group (avoid)", teaching: "GCD.Blocking.blockThisThreadUntilAllJobsEnd", apple: "group.wait"),
    ]

    static let traps: [(said: String, typed: String, meant: String)] = [
        ("“Do it in the background”", ".background", "runUserRequestedWork (.userInitiated)"),
        ("“Async this”", "async", "do not wait — not magic parallelism"),
        ("“Sync so it is safe”", "queue.sync from main", "serial lane / actor, not blocking"),
        ("“Concurrent so it is faster”", "concurrent + shared var", "data race unless isolated"),
    ]
}

enum ModernCheatSheet {
    static let mappings: [CheatSheetRow] = [
        .init(id: "ui", intent: "Change the UI, do not wait", teaching: "Modern.updateUI { }", apple: "Task { @MainActor in }"),
        .init(id: "wait-ui", intent: "Change the UI, suspend until done", teaching: "await Modern.waitForUI { }", apple: "await MainActor.run"),
        .init(id: "ui-after", intent: "Change the UI after a delay", teaching: "Modern.updateUI(after:) { }", apple: "Task.sleep then MainActor.run"),
        .init(id: "high", intent: "UI needs this now (tiny, rare)", teaching: "Modern.runForImmediateUI { }", apple: "Task(priority: .high)"),
        .init(id: "initiated", intent: "User tapped and is waiting", teaching: "Modern.runUserRequestedWork { }", apple: "Task(priority: .userInitiated)"),
        .init(id: "utility", intent: "Progress the user may watch", teaching: "Modern.runMaintenanceWork { }", apple: "Task(priority: .utility)"),
        .init(id: "background", intent: "User is not waiting", teaching: "Modern.runWhenUserIsNotWaiting { }", apple: "Task(priority: .background)"),
        .init(id: "detached", intent: "Do not inherit this actor", teaching: "Modern.runDetachedFromCaller { }", apple: "Task.detached"),
        .init(id: "actor", intent: "One-at-a-time isolated state", teaching: "Modern.ExclusiveState", apple: "actor"),
        .init(id: "group", intent: "Several child tasks, then continue", teaching: "await Modern.runSeveralThenContinue", apple: "withTaskGroup"),
        .init(id: "async-let", intent: "Two named loads at once", teaching: "await Modern.runTwoAtOnce", apple: "async let"),
        .init(id: "sleep", intent: "Delay without blocking a thread", teaching: "await Modern.pauseThisTask(for:)", apple: "Task.sleep"),
        .init(id: "yield", intent: "Give others a turn", teaching: "await Modern.letOthersRun()", apple: "Task.yield"),
        .init(id: "cancel", intent: "Cooperative cancel", teaching: "Modern.makeCancellableWork", apple: "Task.cancel / checkCancellation"),
        .init(id: "cont", intent: "Wrap a completion handler", teaching: "await Modern.waitForCallback", apple: "withCheckedContinuation"),
        .init(id: "park", intent: "Block this thread (avoid)", teaching: "Modern.Blocking.parkThisThreadUntilTaskFinishes", apple: "semaphore.wait around a Task"),
    ]

    static let traps: [(said: String, typed: String, meant: String)] = [
        ("“Do it in the background”", "TaskPriority.background", "runUserRequestedWork (.userInitiated)"),
        ("“Task { } from a button”", "inherits @MainActor", "runDetachedFromCaller if work must leave UI"),
        ("“Await is like sync”", "await", "suspends the task; does not park the thread"),
        ("“Actors can't race”", "await inside the actor", "reentrancy: other callers run at every await"),
        ("“Cancel stops it”", "task.cancel()", "cooperative — sleep checks; CPU loops do not"),
    ]
}

struct CheatSheetView: View {
    let track: LearningTrack
    @Environment(\.dismiss) private var dismiss

    private var mappings: [CheatSheetRow] {
        track == .gcd ? GCDCheatSheet.mappings : ModernCheatSheet.mappings
    }

    private var traps: [(said: String, typed: String, meant: String)] {
        track == .gcd ? GCDCheatSheet.traps : ModernCheatSheet.traps
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Concurrency101 is a dictionary. The intent name is what you call while learning; the Apple name is what you will see in docs and interviews.")
                        .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.82))

                    CheatSheetMappingList(rows: mappings)
                    CheatSheetTrapList(traps: traps)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(DemoTheme.void.ignoresSafeArea())
            .navigationTitle(track == .gcd ? "GCD cheat sheet" : "Swift cheat sheet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DemoTheme.void, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DemoTheme.phosphor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct CheatSheetMappingList: View {
    let rows: [CheatSheetRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(DemoTheme.phosphor.opacity(0.12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.intent)
                        .font(.system(size: DemoLayout.typeSize(13), design: .serif))
                        .foregroundStyle(DemoTheme.muted)
                    Text(row.teaching)
                        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                        .foregroundStyle(DemoTheme.phosphor)
                        .textSelection(.enabled)
                    Text(row.apple)
                        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                        .foregroundStyle(DemoTheme.cyan)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            }
        }
    }
}

private struct CheatSheetTrapList: View {
    let traps: [(said: String, typed: String, meant: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Everyday traps")
                .font(.system(size: DemoLayout.typeSize(18), design: .serif))
                .foregroundStyle(DemoTheme.phosphor)
            ForEach(Array(traps.enumerated()), id: \.offset) { _, trap in
                VStack(alignment: .leading, spacing: 4) {
                    Text(trap.said)
                        .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.86))
                    Text("typed  \(trap.typed)")
                        .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                        .foregroundStyle(DemoTheme.freeze.opacity(0.9))
                    Text("meant  \(trap.meant)")
                        .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                        .foregroundStyle(DemoTheme.cyan)
                }
                .padding(.bottom, 8)
            }
        }
    }
}
