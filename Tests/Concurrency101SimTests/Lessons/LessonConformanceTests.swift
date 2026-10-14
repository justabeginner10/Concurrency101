import XCTest
@testable import Concurrency101Sim

/// Every Playground lesson, both the Concurrency101 snippet and the Apple
/// snippet, must run in the simulator and show what the lesson teaches.
/// The snippets are read from the demo app, so editing a lesson there
/// re-runs these checks.
final class LessonConformanceTests: XCTestCase {
    private typealias Check = (SimRun) -> Void

    private let seeds: [UInt64] = [1, 2, 3, 7]

    private lazy var checks: [String: Check] = [
        // MARK: GCD
        "update-ui": { run in
            assertFinished(run)
            assertOrder("caller continued immediately", before: "decode finished", in: run)
            XCTAssertEqual(event("decode starting", in: run)?.isMainThread, false)
            XCTAssertEqual(event("updateUI: would set", in: run)?.isMainThread, true)
        },
        "delayed-ui": { run in
            assertFinished(run)
            assertOrder("caller continued", before: "delayed updateUI fired", in: run)
            XCTAssertEqual(event("delayed updateUI fired", in: run)?.time ?? 0, 0.6, accuracy: 0.01)
        },
        "qos-names": { run in
            assertFinished(run)
            XCTAssertEqual(event("user-initiated hop running", in: run)?.context, "global(.userInitiated)")
            XCTAssertEqual(event("background hop running", in: run)?.context, "global(.background)")
        },
        "immediate-ui": { run in
            assertFinished(run)
            XCTAssertEqual(event("runForImmediateUI body", in: run)?.context, "global(.userInteractive)")
            XCTAssertEqual(event("then updateUI", in: run)?.isMainThread, true)
        },
        "maintenance": { run in
            assertFinished(run)
            XCTAssertEqual(event("runMaintenanceWork", in: run)?.context, "global(.utility)")
        },
        "serial-race": { run in
            assertFinished(run)
            XCTAssertNotNil(position("serial result: 400 (expected 400)", in: run))
            let racy = run.logLines.first { $0.hasPrefix("racy result:") } ?? ""
            let value = Int(racy.dropFirst("racy result: ".count).prefix { $0.isNumber }) ?? -1
            XCTAssertTrue((300...400).contains(value), racy)
            let lost = run.notes.first { $0.text.contains("'racy'") }
            if value < 400 {
                XCTAssertNotNil(lost, "a lost update should be reported")
                XCTAssertTrue(lost?.text.contains("\(400 - value) update") ?? false, lost?.text ?? "")
            }
            XCTAssertFalse(run.notes.contains { $0.text.contains("'safe'") }, "the serial lane must not race")
        },
        "overlap": { run in
            assertFinished(run)
            assertOrder("first: waiting on gate", before: "second: running while first waits", in: run)
            assertOrder("second: running while first waits", before: "first: released", in: run)
            XCTAssertNotEqual(event("first: waiting", in: run)?.thread, event("second: running", in: run)?.thread)
        },
        "barrier": { run in
            assertFinished(run)
            assertOrder("read A end", before: "WRITE exclusive", in: run)
            assertOrder("read B end", before: "WRITE exclusive", in: run)
            assertOrder("WRITE exclusive", before: "read after write", in: run)
            let aStart = event("read A start", in: run)?.time ?? 1
            let bStart = event("read B start", in: run)?.time ?? 1
            XCTAssertLessThan(abs(aStart - bStart), 0.05, "the two reads overlap")
        },
        "group-notify": { run in
            assertFinished(run)
            assertOrder("caller continued (notify, not wait)", before: "loaded messages", in: run)
            assertOrder("loaded messages", before: "loaded prefs", in: run)
            assertOrder("loaded prefs", before: "loaded profile", in: run)
            assertOrder("loaded profile", before: "screen ready", in: run)
            XCTAssertEqual(event("screen ready", in: run)?.isMainThread, true)
        },
        "missing-leave": { run in
            assertFinished(run)
            XCTAssertNil(position("should NOT appear", in: run))
            XCTAssertNotNil(position("still no finish", in: run))
            XCTAssertTrue(run.notes.contains { $0.text.contains("notify never ran") })
        },
        "enter-leave": { run in
            assertFinished(run)
            assertOrder("callback A", before: "callback B", in: run)
            assertOrder("callback B", before: "both callbacks finished", in: run)
        },
        "work-item": { run in
            assertFinished(run)
            XCTAssertNil(position("THIS SHOULD NOT PRINT", in: run))
            assertOrder("cancelling long item", before: "long item finished sleep", in: run)
            XCTAssertNotNil(position("isCancelled=true", in: run))
        },
        "sync-safe": { run in
            assertFinished(run)
            assertOrder("inside sync body", before: "sync returned", in: run)
            XCTAssertEqual(event("sync returned", in: run)?.time ?? 0, 0.15, accuracy: 0.01)
            XCTAssertEqual(event("inside sync body", in: run)?.isMainThread, true, "sync runs the block on the calling thread")
        },
        "wait-timeout": { run in
            assertFinished(run)
            XCTAssertNotNil(position("wait result: timedOut", in: run))
            XCTAssertEqual(event("wait result", in: run)?.time ?? 0, 0.35, accuracy: 0.01)
        },
        "deadlock": { run in
            guard let s = stall(run) else { return }
            XCTAssertTrue(s.headline.contains("main.sync"), s.headline)
            XCTAssertTrue(s.mainThreadFrozen)
            XCTAssertNil(position("this never prints", in: run))
            XCTAssertNotNil(position("the next line will never appear", in: run))
        },

        // MARK: Swift Concurrency
        "modern-decode-ui": { run in
            assertFinished(run)
            assertOrder("caller continued immediately", before: "decode finished", in: run)
            XCTAssertEqual(event("decode starting", in: run)?.isMainThread, false)
            XCTAssertEqual(event("waitForUI: would set", in: run)?.isMainThread, true)
        },
        "modern-delayed-ui": { run in
            assertFinished(run)
            assertOrder("caller continued", before: "delayed updateUI fired", in: run)
            XCTAssertEqual(event("delayed updateUI fired", in: run)?.isMainThread, true)
            XCTAssertEqual(event("delayed updateUI fired", in: run)?.time ?? 0, 0.6, accuracy: 0.01)
        },
        "modern-priority": { run in
            assertFinished(run)
            XCTAssertNotNil(position("user-initiated hop running", in: run))
            XCTAssertNotNil(position("background hop running", in: run))
        },
        "modern-immediate": { run in
            assertFinished(run)
            XCTAssertEqual(event("then waitForUI", in: run)?.isMainThread, true)
        },
        "modern-maintenance": { run in
            assertFinished(run)
            assertOrder("caller continued", before: "runMaintenanceWork", in: run)
        },
        "modern-detached": { run in
            assertFinished(run)
            XCTAssertEqual(event("Task.detached body", in: run)?.isMainThread, false)
        },
        "modern-actor": { run in
            assertFinished(run)
            XCTAssertNotNil(position("actor result: 400 (expected 400)", in: run))
            XCTAssertTrue(run.notes.isEmpty, "\(run.notes)")
        },
        "modern-group": { run in
            assertFinished(run)
            assertOrder("caller continued", before: "loaded messages", in: run)
            assertOrder("loaded messages", before: "loaded prefs", in: run)
            assertOrder("loaded prefs", before: "loaded profile", in: run)
            assertOrder("loaded profile", before: "screen ready", in: run)
        },
        "modern-async-let": { run in
            assertFinished(run)
            assertOrder("right finished", before: "left finished", in: run)
            assertOrder("left finished", before: "joined: profile, feed", in: run)
            XCTAssertEqual(event("joined", in: run)?.time ?? 0, 0.2, accuracy: 0.01, "both started together, so the join waits for the slower one only")
        },
        "modern-cancel-sleep": { run in
            assertFinished(run)
            XCTAssertNil(position("THIS SHOULD NOT PRINT", in: run))
            assertOrder("sleeping 2s", before: "sleep threw CancellationError", in: run)
            XCTAssertLessThan(run.endTime, 0.1, "cancellation wakes the sleep early")
        },
        "modern-cancel-busy": { run in
            assertFinished(run)
            XCTAssertNotNil(position("busy loop finished (cancel did not abort it)", in: run))
            XCTAssertEqual(event("busy loop finished", in: run)?.time ?? 0, 0.45, accuracy: 0.02)
        },
        "modern-continuation": { run in
            assertFinished(run)
            assertOrder("caller continued", before: "fake callback firing", in: run)
            assertOrder("fake callback firing", before: "got payload", in: run)
            XCTAssertEqual(event("got payload", in: run)?.isMainThread, true)
        },
        "modern-reentrancy": { run in
            assertFinished(run)
            assertOrder("first saw 0", before: "second incremented", in: run)
            assertOrder("second incremented", before: "first writing 1", in: run)
            if position("final:", in: run) != nil {
                XCTAssertNotNil(position("final: 1", in: run), "the second increment is overwritten")
            }
        },
        "modern-await-vs-block": { run in
            assertFinished(run)
            assertOrder("caller continued", before: "task: woke", in: run)
            XCTAssertLessThan(event("caller continued", in: run)?.time ?? 1, 0.01, "the caller was not parked")
        },
        "modern-deadlock": { run in
            guard let s = stall(run) else { return }
            XCTAssertTrue(s.mainThreadFrozen)
            XCTAssertTrue(s.headline.contains("main thread is blocked"), s.headline)
            XCTAssertTrue(s.details.contains { $0.contains("DispatchSemaphore.wait()") }, "\(s.details)")
            XCTAssertNil(position("this never prints", in: run))
        },
    ]

    func testEveryLessonHasAnExpectation() {
        let ids = LessonSnippets.all.map(\.id)
        XCTAssertEqual(ids.count, 30, "lesson count changed: \(ids)")
        for id in ids {
            XCTAssertNotNil(checks[id], "add a simulator expectation for lesson '\(id)'")
        }
    }

    func testEveryLessonCompilesWithoutDiagnostics() {
        for lesson in LessonSnippets.all {
            XCTAssertEqual(Simulator.check(lesson.teaching), [], "\(lesson.id) [101]")
            XCTAssertEqual(Simulator.check(lesson.apple), [], "\(lesson.id) [apple]")
        }
    }

    func testTeachingSnippets() {
        for lesson in LessonSnippets.all {
            guard let check = checks[lesson.id] else { continue }
            for seed in seeds {
                XCTContext.runActivity(named: "\(lesson.id) [101] seed \(seed)") { _ in
                    check(Simulator.run(lesson.teaching, configuration: SimConfiguration(seed: seed)))
                }
            }
        }
    }

    func testAppleSnippets() {
        for lesson in LessonSnippets.all {
            guard let check = checks[lesson.id] else { continue }
            for seed in seeds {
                XCTContext.runActivity(named: "\(lesson.id) [apple] seed \(seed)") { _ in
                    check(Simulator.run(lesson.apple, configuration: SimConfiguration(seed: seed)))
                }
            }
        }
    }

    func testRaceLessonUsuallyLosesUpdates() {
        let lesson = LessonSnippets.named("serial-race")
        let lossy = (UInt64(1)...8).filter { seed in
            let run = Simulator.run(lesson.apple, configuration: SimConfiguration(seed: seed))
            return run.notes.contains { $0.text.contains("'racy'") }
        }
        XCTAssertGreaterThanOrEqual(lossy.count, 4, "the racy counter should lose updates on most seeds")
    }

    func testSameSeedReplaysTheSameRun() {
        let lesson = LessonSnippets.named("serial-race")
        let a = Simulator.run(lesson.apple, configuration: SimConfiguration(seed: 5))
        let b = Simulator.run(lesson.apple, configuration: SimConfiguration(seed: 5))
        XCTAssertEqual(a.events, b.events)
        XCTAssertEqual(a.endTime, b.endTime)
    }
}
