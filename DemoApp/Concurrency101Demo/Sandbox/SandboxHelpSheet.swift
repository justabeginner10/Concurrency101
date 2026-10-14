import SwiftUI

/// What the simulated runtime models, and where it stops.
struct SandboxHelpSheet: View {
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, lines: [String])] = [
        ("What runs", [
            "Your code is parsed, compiled to small steps, and run by a simulator inside the app. No real thread is started, so nothing here can freeze the app.",
            "The code runs like a button action: synchronously, on the main thread, on the main actor. Put async work inside Task { }.",
        ]),
        ("What it models", [
            "One main thread. It runs the main queue and the main actor, one job at a time.",
            "A GCD worker pool. When workers block (sync, sleep, a semaphore), GCD adds more, up to 64.",
            "The Swift task pool: exactly one thread per core, and it never grows. Block in a task and other tasks wait.",
            "Serial and concurrent queues, barriers, groups, semaphores, work items, asyncAfter.",
            "Task, Task.detached, priorities, actors and reentrancy, MainActor.run, async let, task groups, cancellation, continuations.",
            "A virtual clock. Each step costs about 10 µs; sleeps and delays move the clock.",
            "Every Concurrency101 name, written on top of the same Apple call as the real package.",
        ]),
        ("What it doesn't", [
            "Real timings and thread counts. The order of events is realistic; the numbers are illustrative.",
            "Sendable checking and most compile-time isolation rules. Some isolation mistakes show up when the code runs instead.",
            "Most of Foundation and UIKit, structs, protocols, generics and dictionaries.",
            "Nonisolated async functions hop to the pool (SE-0338), the Swift 6.0 default without Approachable Concurrency.",
        ]),
        ("Reading the output", [
            "Trace: virtual time, the thread (amber is main), the line, and the queue, actor or task it ran in.",
            "Threads: one row per thread. Solid is running. Outlined is holding the thread while waiting. A bar that runs off the end never came back.",
            "Shuffle runs the same code with another valid interleaving. The same seed always replays the same run.",
            "Cores changes the size of the task pool. Try one core with blocking code inside tasks.",
        ]),
    ]

    var body: some View {
        NavigationStack {
            DemoCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(sections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verbatim: section.title)
                                    .font(.system(size: DemoLayout.typeSize(18), design: .serif))
                                    .foregroundStyle(accent)
                                ForEach(section.lines, id: \.self) { line in
                                    Text(verbatim: line)
                                        .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                                        .foregroundStyle(Color.white.opacity(0.82))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("How the Sandbox works")
            .demoRoomChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accent)
                }
            }
        }
    }
}
