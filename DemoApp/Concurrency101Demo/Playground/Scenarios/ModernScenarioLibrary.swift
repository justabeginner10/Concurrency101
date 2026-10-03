import Foundation
import Concurrency101

enum ModernScenarioLibrary {
    static let all: [DemoScenario] = [
        decodeThenUI,
        delayedUI,
        userWaitingVersusNot,
        immediateUI,
        maintenance,
        taskVersusDetached,
        actorVersusRace,
        severalThenContinue,
        twoAtOnce,
        cancellableSleep,
        busyLoopIgnoresCancel,
        continuation,
        reentrancy,
        awaitDoesNotBlock,
        parkThreadOnPurpose,
    ]

    static let decodeThenUI = DemoScenario(
        id: "modern-decode-ui",
        title: "Decode, then waitForUI",
        appleAPI: "Task.detached + await MainActor.run",
        blurb: "Leave the main actor for heavy work, then hop back. The caller does not wait.",
        teachingSnippet: """
        log.log("caller: submitting runDetachedFromCaller")
        Concurrency101.Modern.runDetachedFromCaller {
            log.log("decode starting (should be off-main)")
            try? await Concurrency101.Modern.pauseThisTask(for: 0.35)
            log.log("decode finished, hopping to waitForUI")
            await Concurrency101.Modern.waitForUI {
                log.log("waitForUI: would set imageView.image here")
            }
        }
        log.log("caller continued immediately")
        """,
        appleSnippet: """
        log.log("caller: submitting runDetachedFromCaller")
        Task.detached {
            log.log("decode starting (should be off-main)")
            try? await Task.sleep(for: .seconds(0.35))
            log.log("decode finished, hopping to waitForUI")
            await MainActor.run {
                log.log("waitForUI: would set imageView.image here")
            }
        }
        log.log("caller continued immediately")
        """,
        isDestructive: false
    ) { log in
        log.log("caller: submitting runDetachedFromCaller")
        Concurrency101.Modern.runDetachedFromCaller {
            log.log("decode starting (should be off-main)")
            try? await Concurrency101.Modern.pauseThisTask(for: 0.35)
            log.log("decode finished, hopping to waitForUI")
            await Concurrency101.Modern.waitForUI {
                log.log("waitForUI: would set imageView.image here")
            }
        }
        log.log("caller continued immediately")
    }

    static let delayedUI = DemoScenario(
        id: "modern-delayed-ui",
        title: "Update UI after a delay",
        appleAPI: "Task.sleep then MainActor",
        blurb: "The delay suspends a task. It does not park a thread.",
        teachingSnippet: """
        log.log("caller: updateUI(after: 0.6)")
        Concurrency101.Modern.updateUI(after: 0.6) {
            log.log("delayed updateUI fired")
        }
        log.log("caller continued; watch for the delayed line")
        """,
        appleSnippet: """
        log.log("caller: updateUI(after: 0.6)")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            log.log("delayed updateUI fired")
        }
        log.log("caller continued; watch for the delayed line")
        """,
        isDestructive: false
    ) { log in
        log.log("caller: updateUI(after: 0.6)")
        Concurrency101.Modern.updateUI(after: 0.6) {
            log.log("delayed updateUI fired")
        }
        log.log("caller continued; watch for the delayed line")
    }

    static let userWaitingVersusNot = DemoScenario(
        id: "modern-priority",
        title: "User waiting vs not waiting",
        appleAPI: ".userInitiated vs .background",
        blurb: "Everyday “background” is not TaskPriority.background. A Refresh tap is user-initiated.",
        teachingSnippet: """
        log.log("Refresh tap → runUserRequestedWork (.userInitiated)")
        Concurrency101.Modern.runUserRequestedWork {
            log.log("user-initiated hop running")
        }
        log.log("Cache prune → runWhenUserIsNotWaiting (.background)")
        Concurrency101.Modern.runWhenUserIsNotWaiting {
            log.log("background hop running")
        }
        log.log("caller already continued")
        """,
        appleSnippet: """
        log.log("Refresh tap → runUserRequestedWork (.userInitiated)")
        Task(priority: .userInitiated) {
            log.log("user-initiated hop running")
        }
        log.log("Cache prune → runWhenUserIsNotWaiting (.background)")
        Task(priority: .background) {
            log.log("background hop running")
        }
        log.log("caller already continued")
        """,
        isDestructive: false
    ) { log in
        log.log("Refresh tap → runUserRequestedWork (.userInitiated)")
        Concurrency101.Modern.runUserRequestedWork {
            log.log("user-initiated hop running")
        }
        log.log("Cache prune → runWhenUserIsNotWaiting (.background)")
        Concurrency101.Modern.runWhenUserIsNotWaiting {
            log.log("background hop running")
        }
        log.log("caller already continued")
    }

    static let immediateUI = DemoScenario(
        id: "modern-immediate",
        title: "Immediate UI (tiny, rare)",
        appleAPI: "Task(priority: .high)",
        blurb: "Tiny next-frame work. Touching the screen still goes through waitForUI / MainActor.",
        teachingSnippet: """
        Concurrency101.Modern.runForImmediateUI {
            log.log("runForImmediateUI body")
            await Concurrency101.Modern.waitForUI {
                log.log("then waitForUI to commit to the screen")
            }
        }
        log.log("caller continued")
        """,
        appleSnippet: """
        Task(priority: .high) {
            log.log("runForImmediateUI body")
            await MainActor.run {
                log.log("then waitForUI to commit to the screen")
            }
        }
        log.log("caller continued")
        """,
        isDestructive: false
    ) { log in
        Concurrency101.Modern.runForImmediateUI {
            log.log("runForImmediateUI body")
            await Concurrency101.Modern.waitForUI {
                log.log("then waitForUI to commit to the screen")
            }
        }
        log.log("caller continued")
    }

    static let maintenance = DemoScenario(
        id: "modern-maintenance",
        title: "Maintenance work",
        appleAPI: "Task(priority: .utility)",
        blurb: "Longer work the user may notice but is not tap-waiting on.",
        teachingSnippet: """
        Concurrency101.Modern.runMaintenanceWork {
            log.log("runMaintenanceWork (utility)")
        }
        log.log("caller continued")
        """,
        appleSnippet: """
        Task(priority: .utility) {
            log.log("runMaintenanceWork (utility)")
        }
        log.log("caller continued")
        """,
        isDestructive: false
    ) { log in
        Concurrency101.Modern.runMaintenanceWork {
            log.log("runMaintenanceWork (utility)")
        }
        log.log("caller continued")
    }

    static let taskVersusDetached = DemoScenario(
        id: "modern-detached",
        title: "Task vs Task.detached",
        appleAPI: "Task { } inherits @MainActor; Task.detached does not",
        blurb: "Started from the main actor, Task keeps you there. Detached leaves. That is not GCD global.async.",
        teachingSnippet: """
        log.log("on main, starting both")
        Concurrency101.Modern.runUserRequestedWork {
            log.log("Task(priority:) body (often still main)")
        }
        Concurrency101.Modern.runDetachedFromCaller {
            log.log("Task.detached body (should be off-main)")
        }
        """,
        appleSnippet: """
        log.log("on main, starting both")
        Task(priority: .userInitiated) {
            log.log("Task(priority:) body (often still main)")
        }
        Task.detached {
            log.log("Task.detached body (should be off-main)")
        }
        """,
        isDestructive: false
    ) { log in
        log.log("on main, starting both")
        Concurrency101.Modern.runUserRequestedWork {
            log.log("Task(priority:) body (often still main)")
        }
        Concurrency101.Modern.runDetachedFromCaller {
            log.log("Task.detached body (should be off-main)")
        }
    }

    static let actorVersusRace = DemoScenario(
        id: "modern-actor",
        title: "Actor vs data race",
        appleAPI: "actor vs unsynchronized += on overlapping tasks",
        blurb: "ExclusiveState is a teaching actor. Unsynchronized += from a task group is a race.",
        teachingSnippet: """
        let iterations = 400
        let counter = Concurrency101.Modern.ExclusiveState(0)
        log.log("actor: \\(iterations) increments")
        Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<iterations {
                    group.addTask {
                        await counter.modify { $0 += 1 }
                    }
                }
            }
            let safe = await counter.snapshot()
            log.log("actor result: \\(safe) (expected \\(iterations))")
        }
        """,
        appleSnippet: """
        let iterations = 400
        actor Counter {
            var value = 0
            func increment() { value += 1 }
        }
        let counter = Counter()
        log.log("actor: \\(iterations) increments")
        Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<iterations {
                    group.addTask { await counter.increment() }
                }
            }
            log.log("actor result: \\(await counter.value) (expected \\(iterations))")
        }
        """,
        isDestructive: false
    ) { log in
        let iterations = 400
        let counter = Concurrency101.Modern.ExclusiveState(0)
        log.log("actor: \(iterations) increments")
        Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<iterations {
                    group.addTask {
                        await counter.modify { $0 += 1 }
                    }
                }
            }
            let safe = await counter.snapshot()
            log.log("actor result: \(safe) (expected \(iterations))")
        }
    }

    static let severalThenContinue = DemoScenario(
        id: "modern-group",
        title: "Several jobs, then continue",
        appleAPI: "withTaskGroup",
        blurb: "Structured: the await does not return until every child finished. GCD notify does not wait at the call site.",
        teachingSnippet: """
        log.log("submitting three loads inside a Task")
        Task {
            await Concurrency101.Modern.runSeveralThenContinue(
                jobs: [
                    {
                        try? await Concurrency101.Modern.pauseThisTask(for: 0.2)
                        log.log("loaded profile")
                    },
                    {
                        try? await Concurrency101.Modern.pauseThisTask(for: 0.08)
                        log.log("loaded messages")
                    },
                    {
                        try? await Concurrency101.Modern.pauseThisTask(for: 0.14)
                        log.log("loaded prefs")
                    },
                ],
                then: {
                    log.log("screen ready — group joined")
                }
            )
        }
        log.log("caller continued (the Task is unstructured; the group inside is not)")
        """,
        appleSnippet: """
        log.log("submitting three loads inside a Task")
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    try? await Task.sleep(for: .seconds(0.2))
                    log.log("loaded profile")
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(0.08))
                    log.log("loaded messages")
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(0.14))
                    log.log("loaded prefs")
                }
            }
            log.log("screen ready — group joined")
        }
        log.log("caller continued (the Task is unstructured; the group inside is not)")
        """,
        isDestructive: false
    ) { log in
        log.log("submitting three loads inside a Task")
        Task {
            await Concurrency101.Modern.runSeveralThenContinue(
                jobs: [
                    {
                        try? await Concurrency101.Modern.pauseThisTask(for: 0.2)
                        log.log("loaded profile")
                    },
                    {
                        try? await Concurrency101.Modern.pauseThisTask(for: 0.08)
                        log.log("loaded messages")
                    },
                    {
                        try? await Concurrency101.Modern.pauseThisTask(for: 0.14)
                        log.log("loaded prefs")
                    },
                ],
                then: {
                    log.log("screen ready — group joined")
                }
            )
        }
        log.log("caller continued (the Task is unstructured; the group inside is not)")
    }

    static let twoAtOnce = DemoScenario(
        id: "modern-async-let",
        title: "Two loads at once",
        appleAPI: "async let",
        blurb: "Work starts at the async let line. await only joins, in named order.",
        teachingSnippet: """
        log.log("starting runTwoAtOnce")
        Task {
            let pair = await Concurrency101.Modern.runTwoAtOnce(
                {
                    try? await Concurrency101.Modern.pauseThisTask(for: 0.2)
                    log.log("left finished")
                    return "profile"
                },
                {
                    try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
                    log.log("right finished")
                    return "feed"
                }
            )
            log.log("joined: \\(pair.0), \\(pair.1)")
        }
        log.log("caller continued")
        """,
        appleSnippet: """
        log.log("starting runTwoAtOnce")
        Task {
            async let left = {
                try? await Task.sleep(for: .seconds(0.2))
                log.log("left finished")
                return "profile"
            }()
            async let right = {
                try? await Task.sleep(for: .seconds(0.05))
                log.log("right finished")
                return "feed"
            }()
            let pair = await (left, right)
            log.log("joined: \\(pair.0), \\(pair.1)")
        }
        log.log("caller continued")
        """,
        isDestructive: false
    ) { log in
        log.log("starting runTwoAtOnce")
        Task {
            let pair = await Concurrency101.Modern.runTwoAtOnce(
                {
                    try? await Concurrency101.Modern.pauseThisTask(for: 0.2)
                    log.log("left finished")
                    return "profile"
                },
                {
                    try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
                    log.log("right finished")
                    return "feed"
                }
            )
            log.log("joined: \(pair.0), \(pair.1)")
        }
        log.log("caller continued")
    }

    static let cancellableSleep = DemoScenario(
        id: "modern-cancel-sleep",
        title: "Cancel a sleeping task",
        appleAPI: "Task.cancel + Task.sleep throws CancellationError",
        blurb: "Sleep checks the cancellation flag for you.",
        teachingSnippet: """
        let task = Concurrency101.Modern.makeCancellableWork {
            do {
                log.log("sleeping 2s")
                try await Concurrency101.Modern.pauseThisTask(for: 2)
                log.log("THIS SHOULD NOT PRINT")
            } catch is CancellationError {
                log.log("sleep threw CancellationError")
            } catch {
                log.log("unexpected \\(error)")
            }
        }
        log.log("cancelling immediately")
        task.cancel()
        """,
        appleSnippet: """
        let task = Task {
            do {
                log.log("sleeping 2s")
                try await Task.sleep(for: .seconds(2))
                log.log("THIS SHOULD NOT PRINT")
            } catch is CancellationError {
                log.log("sleep threw CancellationError")
            } catch {
                log.log("unexpected \\(error)")
            }
        }
        log.log("cancelling immediately")
        task.cancel()
        """,
        isDestructive: false
    ) { log in
        let task = Concurrency101.Modern.makeCancellableWork {
            do {
                log.log("sleeping 2s")
                try await Concurrency101.Modern.pauseThisTask(for: 2)
                log.log("THIS SHOULD NOT PRINT")
            } catch is CancellationError {
                log.log("sleep threw CancellationError")
            } catch {
                log.log("unexpected \(error)")
            }
        }
        log.log("cancelling immediately")
        task.cancel()
    }

    static let busyLoopIgnoresCancel = DemoScenario(
        id: "modern-cancel-busy",
        title: "Cancel does not abort CPU",
        appleAPI: "Task.cancel is a flag; a busy loop never reads it",
        blurb: "Same cooperative rule as DispatchWorkItem. Put checkpoints in loops.",
        teachingSnippet: """
        let task = Concurrency101.Modern.makeCancellableWork {
            log.log("busy loop started")
            let deadline = Date().addingTimeInterval(0.45)
            while Date() < deadline {}
            log.log("busy loop finished (cancel did not abort it), cancelled=\\(Concurrency101.Modern.isCurrentTaskCancelled)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            log.log("cancelling while the loop runs")
            task.cancel()
        }
        """,
        appleSnippet: """
        let task = Task {
            log.log("busy loop started")
            let deadline = Date().addingTimeInterval(0.45)
            while Date() < deadline {}
            log.log("busy loop finished (cancel did not abort it), cancelled=\\(Task.isCancelled)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            log.log("cancelling while the loop runs")
            task.cancel()
        }
        """,
        isDestructive: false
    ) { log in
        let task = Concurrency101.Modern.makeCancellableWork {
            log.log("busy loop started")
            let deadline = Date().addingTimeInterval(0.45)
            while Date() < deadline {}
            log.log("busy loop finished (cancel did not abort it), cancelled=\(Concurrency101.Modern.isCurrentTaskCancelled)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            log.log("cancelling while the loop runs")
            task.cancel()
        }
    }

    static let continuation = DemoScenario(
        id: "modern-continuation",
        title: "Wrap a callback",
        appleAPI: "withCheckedContinuation",
        blurb: "Resume exactly once. This is how GCD-style callbacks become await.",
        teachingSnippet: """
        log.log("awaiting waitForCallback")
        Task {
            let value = await Concurrency101.Modern.waitForCallback { continuation in
                Concurrency101.GCD.runUserRequestedWork {
                    log.log("fake callback firing")
                    continuation.resume(returning: "payload")
                }
            }
            await Concurrency101.Modern.waitForUI {
                log.log("got \\(value)")
            }
        }
        log.log("caller continued")
        """,
        appleSnippet: """
        log.log("awaiting waitForCallback")
        Task {
            let value = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    log.log("fake callback firing")
                    continuation.resume(returning: "payload")
                }
            }
            await MainActor.run {
                log.log("got \\(value)")
            }
        }
        log.log("caller continued")
        """,
        isDestructive: false
    ) { log in
        log.log("awaiting waitForCallback")
        Task {
            let value = await Concurrency101.Modern.waitForCallback { continuation in
                Concurrency101.GCD.runUserRequestedWork {
                    log.log("fake callback firing")
                    continuation.resume(returning: "payload")
                }
            }
            await Concurrency101.Modern.waitForUI {
                log.log("got \(value)")
            }
        }
        log.log("caller continued")
    }

    static let reentrancy = DemoScenario(
        id: "modern-reentrancy",
        title: "Actor reentrancy",
        appleAPI: "await inside an actor method",
        blurb: "After await, another caller may have run. Isolation is not a lock held across suspension.",
        teachingSnippet: """
        let counter = Concurrency101.Modern.ExclusiveState(0)
        log.log("first: read, sleep, write current+1")
        Task {
            await counter.readAwaitWrite { current in
                log.log("first saw \\(current), now awaiting")
                try? await Concurrency101.Modern.pauseThisTask(for: 0.25)
                log.log("first writing \\(current + 1)")
                return current + 1
            }
            let final = await counter.snapshot()
            log.log("final: \\(final) — often 1, not 2")
        }
        Task {
            try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
            await counter.modify { $0 += 1 }
            log.log("second incremented")
        }
        """,
        appleSnippet: """
        actor Counter {
            var value = 0
            func readAwaitWrite(_ body: (Int) async -> Int) async {
                let current = value
                value = await body(current)
            }
            func increment() { value += 1 }
        }
        let counter = Counter()
        log.log("first: read, sleep, write current+1")
        Task {
            await counter.readAwaitWrite { current in
                log.log("first saw \\(current), now awaiting")
                try? await Task.sleep(for: .seconds(0.25))
                log.log("first writing \\(current + 1)")
                return current + 1
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(0.05))
            await counter.increment()
            log.log("second incremented")
        }
        """,
        isDestructive: false
    ) { log in
        let counter = Concurrency101.Modern.ExclusiveState(0)
        log.log("first: read, sleep, write current+1")
        Task {
            await counter.readAwaitWrite { current in
                log.log("first saw \(current), now awaiting")
                try? await Concurrency101.Modern.pauseThisTask(for: 0.25)
                log.log("first writing \(current + 1)")
                return current + 1
            }
            let final = await counter.snapshot()
            log.log("final: \(final) — often 1, not 2")
        }
        Task {
            try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
            await counter.modify { $0 += 1 }
            log.log("second incremented")
        }
    }

    static let awaitDoesNotBlock = DemoScenario(
        id: "modern-await-vs-block",
        title: "await does not block",
        appleAPI: "Task.sleep suspends; Thread.sleep parks",
        blurb: "The caller continues. The sleeping task is not sitting on a reserved thread.",
        teachingSnippet: """
        log.log("starting a 0.5s pauseThisTask")
        Concurrency101.Modern.runDetachedFromCaller {
            log.log("task: sleeping")
            try? await Concurrency101.Modern.pauseThisTask(for: 0.5)
            log.log("task: woke")
        }
        log.log("caller continued — this thread was not parked")
        """,
        appleSnippet: """
        log.log("starting a 0.5s pauseThisTask")
        Task.detached {
            log.log("task: sleeping")
            try? await Task.sleep(for: .seconds(0.5))
            log.log("task: woke")
        }
        log.log("caller continued — this thread was not parked")
        """,
        isDestructive: false
    ) { log in
        log.log("starting a 0.5s pauseThisTask")
        Concurrency101.Modern.runDetachedFromCaller {
            log.log("task: sleeping")
            try? await Concurrency101.Modern.pauseThisTask(for: 0.5)
            log.log("task: woke")
        }
        log.log("caller continued — this thread was not parked")
    }

    static let parkThreadOnPurpose = DemoScenario(
        id: "modern-deadlock",
        title: "Park thread on purpose",
        appleAPI: "semaphore.wait around await MainActor.run from main",
        blurb: "Freezes the app. The Swift cousin of main.sync. Stop the run in Xcode to recover.",
        teachingSnippet: """
        log.log("parking this thread until waitForUI runs")
        log.log("the next line will never appear — UI is frozen")
        Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
            await Concurrency101.Modern.waitForUI {
                log.log("this never prints")
            }
        }
        log.log("this never prints either")
        """,
        appleSnippet: """
        log.log("parking this thread until waitForUI runs")
        log.log("the next line will never appear — UI is frozen")
        let gate = DispatchSemaphore(value: 0)
        Task.detached {
            await MainActor.run {
                log.log("this never prints")
            }
            gate.signal()
        }
        gate.wait()
        log.log("this never prints either")
        """,
        isDestructive: true
    ) { log in
        log.log("parking this thread until waitForUI runs")
        log.log("the next line will never appear — UI is frozen")
        Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
            await Concurrency101.Modern.waitForUI {
                log.log("this never prints")
            }
        }
        log.log("this never prints either")
    }
}
