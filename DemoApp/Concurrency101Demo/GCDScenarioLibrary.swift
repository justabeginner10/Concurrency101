import Foundation
import Concurrency101

struct DemoScenario: Identifiable {
    let id: String
    let title: String
    let appleAPI: String
    let blurb: String
    let teachingSnippet: String
    let appleSnippet: String
    let isDestructive: Bool
    let run: (DemoLog) -> Void
}

enum GCDScenarioLibrary {
    static let all: [DemoScenario] = [
        updateUI,
        delayedUI,
        userWaitingVersusNot,
        immediateUI,
        maintenance,
        serialVersusRace,
        concurrentOverlap,
        barrier,
        severalThenContinue,
        missingEndOne,
        completionCounterOK,
        cancellableWork,
        blockingSyncSafe,
        blockingWaitTimeout,
        deadlockOnPurpose,
    ]

    static let updateUI = DemoScenario(
        id: "update-ui",
        title: "Decode, then update UI",
        appleAPI: "global(.userInitiated).async + main.async",
        blurb: "Heavy work off the main queue, then hop to main for UI. The caller does not wait.",
        teachingSnippet: """
        log.log("caller: submitting runUserRequestedWork")
        Concurrency101.GCD.runUserRequestedWork {
            log.log("decode starting (should be off-main)")
            Thread.sleep(forTimeInterval: 0.35)
            log.log("decode finished, hopping to updateUI")
            Concurrency101.GCD.updateUI {
                log.log("updateUI: would set imageView.image here")
            }
        }
        log.log("caller continued immediately")
        """,
        appleSnippet: """
        log.log("caller: submitting runUserRequestedWork")
        DispatchQueue.global(qos: .userInitiated).async {
            log.log("decode starting (should be off-main)")
            Thread.sleep(forTimeInterval: 0.35)
            log.log("decode finished, hopping to updateUI")
            DispatchQueue.main.async {
                log.log("updateUI: would set imageView.image here")
            }
        }
        log.log("caller continued immediately")
        """,
        isDestructive: false
    ) { log in
        log.log("caller: submitting runUserRequestedWork")
        Concurrency101.GCD.runUserRequestedWork {
            log.log("decode starting (should be off-main)")
            Thread.sleep(forTimeInterval: 0.35)
            log.log("decode finished, hopping to updateUI")
            Concurrency101.GCD.updateUI {
                log.log("updateUI: would set imageView.image here")
            }
        }
        log.log("caller continued immediately")
    }

    static let delayedUI = DemoScenario(
        id: "delayed-ui",
        title: "Update UI after a delay",
        appleAPI: "main.asyncAfter",
        blurb: "The delay is the earliest the work may run, not a sleeping thread.",
        teachingSnippet: """
        log.log("caller: updateUI(after: 0.6)")
        Concurrency101.GCD.updateUI(after: 0.6) {
            log.log("delayed updateUI fired")
        }
        log.log("caller continued; watch for the delayed line")
        """,
        appleSnippet: """
        log.log("caller: updateUI(after: 0.6)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            log.log("delayed updateUI fired")
        }
        log.log("caller continued; watch for the delayed line")
        """,
        isDestructive: false
    ) { log in
        log.log("caller: updateUI(after: 0.6)")
        Concurrency101.GCD.updateUI(after: 0.6) {
            log.log("delayed updateUI fired")
        }
        log.log("caller continued; watch for the delayed line")
    }

    static let userWaitingVersusNot = DemoScenario(
        id: "qos-names",
        title: "User waiting vs not waiting",
        appleAPI: ".userInitiated vs .background",
        blurb: "Everyday “background” is not GCD .background. A Refresh tap is user-initiated.",
        teachingSnippet: """
        log.log("Refresh tap → runUserRequestedWork (.userInitiated)")
        Concurrency101.GCD.runUserRequestedWork {
            log.log("user-initiated hop running")
        }
        log.log("Cache prune → runWhenUserIsNotWaiting (.background)")
        Concurrency101.GCD.runWhenUserIsNotWaiting {
            log.log("background hop running")
        }
        log.log("caller already continued")
        """,
        appleSnippet: """
        log.log("Refresh tap → runUserRequestedWork (.userInitiated)")
        DispatchQueue.global(qos: .userInitiated).async {
            log.log("user-initiated hop running")
        }
        log.log("Cache prune → runWhenUserIsNotWaiting (.background)")
        DispatchQueue.global(qos: .background).async {
            log.log("background hop running")
        }
        log.log("caller already continued")
        """,
        isDestructive: false
    ) { log in
        log.log("Refresh tap → runUserRequestedWork (.userInitiated)")
        Concurrency101.GCD.runUserRequestedWork {
            log.log("user-initiated hop running")
        }
        log.log("Cache prune → runWhenUserIsNotWaiting (.background)")
        Concurrency101.GCD.runWhenUserIsNotWaiting {
            log.log("background hop running")
        }
        log.log("caller already continued")
    }

    static let immediateUI = DemoScenario(
        id: "immediate-ui",
        title: "Immediate UI (tiny, rare)",
        appleAPI: "global(.userInteractive).async",
        blurb: "Tiny next-frame work. Touching the screen still goes through updateUI / main.",
        teachingSnippet: """
        Concurrency101.GCD.runForImmediateUI {
            log.log("runForImmediateUI body")
            Concurrency101.GCD.updateUI {
                log.log("then updateUI to commit to the screen")
            }
        }
        log.log("caller continued")
        """,
        appleSnippet: """
        DispatchQueue.global(qos: .userInteractive).async {
            log.log("runForImmediateUI body")
            DispatchQueue.main.async {
                log.log("then updateUI to commit to the screen")
            }
        }
        log.log("caller continued")
        """,
        isDestructive: false
    ) { log in
        Concurrency101.GCD.runForImmediateUI {
            log.log("runForImmediateUI body")
            Concurrency101.GCD.updateUI {
                log.log("then updateUI to commit to the screen")
            }
        }
        log.log("caller continued")
    }

    static let maintenance = DemoScenario(
        id: "maintenance",
        title: "Maintenance work",
        appleAPI: "global(.utility).async",
        blurb: "Longer work the user may notice but is not tap-waiting on.",
        teachingSnippet: """
        Concurrency101.GCD.runMaintenanceWork {
            log.log("runMaintenanceWork (utility)")
        }
        log.log("caller continued")
        """,
        appleSnippet: """
        DispatchQueue.global(qos: .utility).async {
            log.log("runMaintenanceWork (utility)")
        }
        log.log("caller continued")
        """,
        isDestructive: false
    ) { log in
        Concurrency101.GCD.runMaintenanceWork {
            log.log("runMaintenanceWork (utility)")
        }
        log.log("caller continued")
    }

    static let serialVersusRace = DemoScenario(
        id: "serial-race",
        title: "Serial lane vs data race",
        appleAPI: "serial DispatchQueue vs overlapping global async",
        blurb: "One-at-a-time isolation versus unsynchronized += on a concurrent pool.",
        teachingSnippet: """
        let iterations = 400
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.demo.counter")
        var safe = 0
        let safeGroup = DispatchGroup()
        log.log("serial lane: \\(iterations) increments")
        for _ in 0..<iterations {
            safeGroup.enter()
            Concurrency101.GCD.runOnLane(lane) {
                safe += 1
                safeGroup.leave()
            }
        }
        safeGroup.notify(queue: .main) {
            log.log("serial result: \\(safe) (expected \\(iterations))")
            var racy = 0
            let racyGroup = DispatchGroup()
            log.log("racy global hops: \\(iterations) unsynchronized +=")
            for _ in 0..<iterations {
                racyGroup.enter()
                Concurrency101.GCD.runUserRequestedWork {
                    racy += 1
                    racyGroup.leave()
                }
            }
            racyGroup.notify(queue: .main) {
                log.log("racy result: \\(racy) (expected \\(iterations); often less)")
            }
        }
        """,
        appleSnippet: """
        let iterations = 400
        let lane = DispatchQueue(label: "com.concurrency101.demo.counter")
        var safe = 0
        let safeGroup = DispatchGroup()
        log.log("serial lane: \\(iterations) increments")
        for _ in 0..<iterations {
            safeGroup.enter()
            lane.async {
                safe += 1
                safeGroup.leave()
            }
        }
        safeGroup.notify(queue: .main) {
            log.log("serial result: \\(safe) (expected \\(iterations))")
            var racy = 0
            let racyGroup = DispatchGroup()
            log.log("racy global hops: \\(iterations) unsynchronized +=")
            for _ in 0..<iterations {
                racyGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    racy += 1
                    racyGroup.leave()
                }
            }
            racyGroup.notify(queue: .main) {
                log.log("racy result: \\(racy) (expected \\(iterations); often less)")
            }
        }
        """,
        isDestructive: false
    ) { log in
        let iterations = 400
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.demo.counter")
        var safe = 0
        let safeGroup = DispatchGroup()
        log.log("serial lane: \(iterations) increments")
        for _ in 0..<iterations {
            safeGroup.enter()
            Concurrency101.GCD.runOnLane(lane) {
                safe += 1
                safeGroup.leave()
            }
        }
        safeGroup.notify(queue: .main) {
            log.log("serial result: \(safe) (expected \(iterations))")
            var racy = 0
            let racyGroup = DispatchGroup()
            log.log("racy global hops: \(iterations) unsynchronized +=")
            for _ in 0..<iterations {
                racyGroup.enter()
                Concurrency101.GCD.runUserRequestedWork {
                    racy += 1
                    racyGroup.leave()
                }
            }
            racyGroup.notify(queue: .main) {
                log.log("racy result: \(racy) (expected \(iterations); often less)")
            }
        }
    }

    static let concurrentOverlap = DemoScenario(
        id: "overlap",
        title: "Concurrent lane can overlap",
        appleAPI: "concurrent DispatchQueue.async",
        blurb: "First item waits; second still runs. That cannot happen on a serial lane.",
        teachingSnippet: """
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.demo.overlap")
        let gate = DispatchSemaphore(value: 0)
        log.log("first item will wait; second should run anyway")
        Concurrency101.GCD.runOnLane(lane) {
            log.log("first: waiting on gate")
            gate.wait()
            log.log("first: released")
        }
        Concurrency101.GCD.runOnLane(lane) {
            log.log("second: running while first waits — overlap")
            gate.signal()
        }
        """,
        appleSnippet: """
        let lane = DispatchQueue(
            label: "com.concurrency101.demo.overlap",
            attributes: .concurrent
        )
        let gate = DispatchSemaphore(value: 0)
        log.log("first item will wait; second should run anyway")
        lane.async {
            log.log("first: waiting on gate")
            gate.wait()
            log.log("first: released")
        }
        lane.async {
            log.log("second: running while first waits — overlap")
            gate.signal()
        }
        """,
        isDestructive: false
    ) { log in
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.demo.overlap")
        let gate = DispatchSemaphore(value: 0)
        log.log("first item will wait; second should run anyway")
        Concurrency101.GCD.runOnLane(lane) {
            log.log("first: waiting on gate")
            gate.wait()
            log.log("first: released")
        }
        Concurrency101.GCD.runOnLane(lane) {
            log.log("second: running while first waits — overlap")
            gate.signal()
        }
    }

    static let barrier = DemoScenario(
        id: "barrier",
        title: "Exclusive write (barrier)",
        appleAPI: "async(flags: .barrier) on a custom concurrent queue",
        blurb: "Reads may overlap. The write waits for in-flight work, then nothing overlaps it.",
        teachingSnippet: """
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.demo.cache")
        Concurrency101.GCD.runOnLane(lane) {
            log.log("read A start")
            Thread.sleep(forTimeInterval: 0.2)
            log.log("read A end")
        }
        Concurrency101.GCD.runOnLane(lane) {
            log.log("read B start")
            Thread.sleep(forTimeInterval: 0.2)
            log.log("read B end")
        }
        Concurrency101.GCD.runExclusiveWrite(on: lane) {
            log.log("WRITE exclusive")
        }
        Concurrency101.GCD.runOnLane(lane) {
            log.log("read after write")
        }
        """,
        appleSnippet: """
        let lane = DispatchQueue(
            label: "com.concurrency101.demo.cache",
            attributes: .concurrent
        )
        lane.async {
            log.log("read A start")
            Thread.sleep(forTimeInterval: 0.2)
            log.log("read A end")
        }
        lane.async {
            log.log("read B start")
            Thread.sleep(forTimeInterval: 0.2)
            log.log("read B end")
        }
        lane.async(flags: .barrier) {
            log.log("WRITE exclusive")
        }
        lane.async {
            log.log("read after write")
        }
        """,
        isDestructive: false
    ) { log in
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.demo.cache")
        Concurrency101.GCD.runOnLane(lane) {
            log.log("read A start")
            Thread.sleep(forTimeInterval: 0.2)
            log.log("read A end")
        }
        Concurrency101.GCD.runOnLane(lane) {
            log.log("read B start")
            Thread.sleep(forTimeInterval: 0.2)
            log.log("read B end")
        }
        Concurrency101.GCD.runExclusiveWrite(on: lane) {
            log.log("WRITE exclusive")
        }
        Concurrency101.GCD.runOnLane(lane) {
            log.log("read after write")
        }
    }

    static let severalThenContinue = DemoScenario(
        id: "group-notify",
        title: "Several jobs, then continue",
        appleAPI: "DispatchGroup.notify",
        blurb: "The group only counts. notify is async — the caller does not wait.",
        teachingSnippet: """
        log.log("submitting three loads")
        Concurrency101.GCD.runSeveralThenContinue(
            jobs: [
                {
                    Thread.sleep(forTimeInterval: 0.2)
                    log.log("loaded profile")
                },
                {
                    Thread.sleep(forTimeInterval: 0.08)
                    log.log("loaded messages")
                },
                {
                    Thread.sleep(forTimeInterval: 0.14)
                    log.log("loaded prefs")
                },
            ],
            then: {
                log.log("screen ready (finish queue is main)")
            }
        )
        log.log("caller continued (notify, not wait)")
        """,
        appleSnippet: """
        log.log("submitting three loads")
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async(group: group) {
            Thread.sleep(forTimeInterval: 0.2)
            log.log("loaded profile")
        }
        queue.async(group: group) {
            Thread.sleep(forTimeInterval: 0.08)
            log.log("loaded messages")
        }
        queue.async(group: group) {
            Thread.sleep(forTimeInterval: 0.14)
            log.log("loaded prefs")
        }
        group.notify(queue: .main) {
            log.log("screen ready (finish queue is main)")
        }
        log.log("caller continued (notify, not wait)")
        """,
        isDestructive: false
    ) { log in
        log.log("submitting three loads")
        Concurrency101.GCD.runSeveralThenContinue(
            jobs: [
                {
                    Thread.sleep(forTimeInterval: 0.2)
                    log.log("loaded profile")
                },
                {
                    Thread.sleep(forTimeInterval: 0.08)
                    log.log("loaded messages")
                },
                {
                    Thread.sleep(forTimeInterval: 0.14)
                    log.log("loaded prefs")
                },
            ],
            then: {
                log.log("screen ready (finish queue is main)")
            }
        )
        log.log("caller continued (notify, not wait)")
    }

    static let missingEndOne = DemoScenario(
        id: "missing-leave",
        title: "Forgot endOne / leave",
        appleAPI: "DispatchGroup.enter without leave",
        blurb: "finish never runs. This demo does not call extra leave (that would trap).",
        teachingSnippet: """
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()
        log.log("beginOne (enter). Forgetting endOne on purpose.")
        counter.whenAllHaveEnded {
            log.log("whenAllHaveEnded — this should NOT appear")
        }
        Concurrency101.GCD.updateUI(after: 0.8) {
            log.log("still no finish — missing leave() is why")
        }
        """,
        appleSnippet: """
        let group = DispatchGroup()
        group.enter()
        log.log("beginOne (enter). Forgetting endOne on purpose.")
        group.notify(queue: .main) {
            log.log("whenAllHaveEnded — this should NOT appear")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            log.log("still no finish — missing leave() is why")
        }
        """,
        isDestructive: false
    ) { log in
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()
        log.log("beginOne (enter). Forgetting endOne on purpose.")
        counter.whenAllHaveEnded {
            log.log("whenAllHaveEnded — this should NOT appear")
        }
        Concurrency101.GCD.updateUI(after: 0.8) {
            log.log("still no finish — missing leave() is why")
        }
    }

    static let completionCounterOK = DemoScenario(
        id: "enter-leave",
        title: "CompletionCounter balanced",
        appleAPI: "enter / leave / notify",
        blurb: "beginOne before each callback; endOne on every completion path.",
        teachingSnippet: """
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()
        counter.beginOne()
        log.log("two beginOne; fake callbacks will endOne")
        counter.whenAllHaveEnded {
            log.log("whenAllHaveEnded — both callbacks finished")
        }
        Concurrency101.GCD.runUserRequestedWork {
            Thread.sleep(forTimeInterval: 0.12)
            log.log("callback A")
            counter.endOne()
        }
        Concurrency101.GCD.runUserRequestedWork {
            Thread.sleep(forTimeInterval: 0.2)
            log.log("callback B")
            counter.endOne()
        }
        """,
        appleSnippet: """
        let group = DispatchGroup()
        group.enter()
        group.enter()
        log.log("two beginOne; fake callbacks will endOne")
        group.notify(queue: .main) {
            log.log("whenAllHaveEnded — both callbacks finished")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 0.12)
            log.log("callback A")
            group.leave()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 0.2)
            log.log("callback B")
            group.leave()
        }
        """,
        isDestructive: false
    ) { log in
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()
        counter.beginOne()
        log.log("two beginOne; fake callbacks will endOne")
        counter.whenAllHaveEnded {
            log.log("whenAllHaveEnded — both callbacks finished")
        }
        Concurrency101.GCD.runUserRequestedWork {
            Thread.sleep(forTimeInterval: 0.12)
            log.log("callback A")
            counter.endOne()
        }
        Concurrency101.GCD.runUserRequestedWork {
            Thread.sleep(forTimeInterval: 0.2)
            log.log("callback B")
            counter.endOne()
        }
    }

    static let cancellableWork = DemoScenario(
        id: "work-item",
        title: "Cancellable work item",
        appleAPI: "DispatchWorkItem.cancel",
        blurb: "Cancel before start skips the body. Cancel during a sleep does not abort it.",
        teachingSnippet: """
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.demo.work")
        let skipped = Concurrency101.GCD.makeCancellableWork {
            log.log("THIS SHOULD NOT PRINT")
        }
        skipped.cancel()
        lane.async(execute: skipped)
        log.log("cancelled item submitted — body skipped")

        let longItem = Concurrency101.GCD.makeCancellableWork {
            log.log("long item started")
            Thread.sleep(forTimeInterval: 0.45)
            log.log("long item finished sleep (cancel did not abort it)")
        }
        lane.async(execute: longItem)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) {
            log.log("cancelling long item while it sleeps")
            longItem.cancel()
        }
        longItem.notify(queue: .main) {
            log.log("notify: long item done, isCancelled=\\(longItem.isCancelled)")
        }
        """,
        appleSnippet: """
        let lane = DispatchQueue(label: "com.concurrency101.demo.work")
        let skipped = DispatchWorkItem {
            log.log("THIS SHOULD NOT PRINT")
        }
        skipped.cancel()
        lane.async(execute: skipped)
        log.log("cancelled item submitted — body skipped")

        let longItem = DispatchWorkItem {
            log.log("long item started")
            Thread.sleep(forTimeInterval: 0.45)
            log.log("long item finished sleep (cancel did not abort it)")
        }
        lane.async(execute: longItem)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) {
            log.log("cancelling long item while it sleeps")
            longItem.cancel()
        }
        longItem.notify(queue: .main) {
            log.log("notify: long item done, isCancelled=\\(longItem.isCancelled)")
        }
        """,
        isDestructive: false
    ) { log in
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.demo.work")
        let skipped = Concurrency101.GCD.makeCancellableWork {
            log.log("THIS SHOULD NOT PRINT")
        }
        skipped.cancel()
        lane.async(execute: skipped)
        log.log("cancelled item submitted — body skipped")

        let longItem = Concurrency101.GCD.makeCancellableWork {
            log.log("long item started")
            Thread.sleep(forTimeInterval: 0.45)
            log.log("long item finished sleep (cancel did not abort it)")
        }
        lane.async(execute: longItem)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) {
            log.log("cancelling long item while it sleeps")
            longItem.cancel()
        }
        longItem.notify(queue: .main) {
            log.log("notify: long item done, isCancelled=\(longItem.isCancelled)")
        }
    }

    static let blockingSyncSafe = DemoScenario(
        id: "sync-safe",
        title: "Block this thread (safe lane)",
        appleAPI: "queue.sync on a private serial queue",
        blurb: "Parks the caller until work finishes. Safe because this lane is not the main queue.",
        teachingSnippet: """
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.demo.sync")
        log.log("about to blockThisThreadUntilFinished on a private lane")
        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: lane) {
            log.log("inside sync body")
            Thread.sleep(forTimeInterval: 0.15)
        }
        log.log("sync returned — caller waited")
        """,
        appleSnippet: """
        let lane = DispatchQueue(label: "com.concurrency101.demo.sync")
        log.log("about to blockThisThreadUntilFinished on a private lane")
        lane.sync {
            log.log("inside sync body")
            Thread.sleep(forTimeInterval: 0.15)
        }
        log.log("sync returned — caller waited")
        """,
        isDestructive: false
    ) { log in
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.demo.sync")
        log.log("about to blockThisThreadUntilFinished on a private lane")
        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: lane) {
            log.log("inside sync body")
            Thread.sleep(forTimeInterval: 0.15)
        }
        log.log("sync returned — caller waited")
    }

    static let blockingWaitTimeout = DemoScenario(
        id: "wait-timeout",
        title: "Wait for a group (timeout)",
        appleAPI: "DispatchGroup.wait",
        blurb: "Parks this thread. Unbalanced enter times out. Then endOne cleans up.",
        teachingSnippet: """
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()
        log.log("waiting 0.35s for a group that never leaves…")
        let outcome = Concurrency101.GCD.Blocking.blockThisThreadUntilAllJobsEnd(
            counter,
            timeout: .now() + 0.35
        )
        log.log("wait result: \\(String(describing: outcome))")
        counter.endOne()
        log.log("balanced after timeout so the group is not stuck")
        """,
        appleSnippet: """
        let group = DispatchGroup()
        group.enter()
        log.log("waiting 0.35s for a group that never leaves…")
        let outcome = group.wait(timeout: .now() + 0.35)
        log.log("wait result: \\(String(describing: outcome))")
        group.leave()
        log.log("balanced after timeout so the group is not stuck")
        """,
        isDestructive: false
    ) { log in
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()
        log.log("waiting 0.35s for a group that never leaves…")
        let outcome = Concurrency101.GCD.Blocking.blockThisThreadUntilAllJobsEnd(
            counter,
            timeout: .now() + 0.35
        )
        log.log("wait result: \(String(describing: outcome))")
        counter.endOne()
        log.log("balanced after timeout so the group is not stuck")
    }

    static let deadlockOnPurpose = DemoScenario(
        id: "deadlock",
        title: "Deadlock on purpose",
        appleAPI: "DispatchQueue.main.sync from the main thread",
        blurb: "Freezes the app. Stop the run in Xcode to recover.",
        teachingSnippet: """
        log.log("calling blockThisThreadUntilFinished(on: .main) from main")
        log.log("the next line will never appear — UI is frozen")
        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main) {
            log.log("this never prints")
        }
        log.log("this never prints either")
        """,
        appleSnippet: """
        log.log("calling blockThisThreadUntilFinished(on: .main) from main")
        log.log("the next line will never appear — UI is frozen")
        DispatchQueue.main.sync {
            log.log("this never prints")
        }
        log.log("this never prints either")
        """,
        isDestructive: true
    ) { log in
        log.log("calling blockThisThreadUntilFinished(on: .main) from main")
        log.log("the next line will never appear — UI is frozen")
        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main) {
            log.log("this never prints")
        }
        log.log("this never prints either")
    }
}
