import XCTest
@testable import Concurrency101Sim

final class GCDModelTests: XCTestCase {
    func testSyncOntoTheSerialQueueYouAreOnDeadlocks() {
        let run = simulate("""
        let q = DispatchQueue(label: "lane")
        q.async {
            log.log("outer")
            q.sync { log.log("inner") }
        }
        """)
        guard let s = stall(run) else { return }
        XCTAssertTrue(s.headline.contains("serial queue 'lane'"), s.headline)
        XCTAssertFalse(s.mainThreadFrozen)
        XCTAssertEqual(lines(run), ["outer"])
    }

    func testMainSyncFromABackgroundThreadRunsOnMainAndReturnsAValue() {
        let run = simulate("""
        DispatchQueue.global().async {
            let n = DispatchQueue.main.sync { () -> Int in
                log.log("on main: \\(Thread.isMainThread)")
                return 42
            }
            log.log("got \\(n) on main: \\(Thread.isMainThread)")
        }
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["on main: true", "got 42 on main: false"])
    }

    func testBlockedWorkersMakeGCDAddThreads() {
        // GCD adds workers when the ones it has are blocked, so eight
        // sleeping blocks finish together even on two cores.
        let run = simulate("""
        let group = DispatchGroup()
        for i in 0..<8 {
            DispatchQueue.global().async(group: group) {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        group.notify(queue: .main) { log.log("all done") }
        """, cores: 2)
        assertFinished(run)
        XCTAssertEqual(event("all done", in: run)?.time ?? 0, 0.1, accuracy: 0.02)
        XCTAssertGreaterThanOrEqual(run.lanes.filter { $0.kind == .gcd }.count, 8)
    }

    func testBarrierOnAGlobalQueueIsIgnoredWithAWarning() {
        let run = simulate("""
        DispatchQueue.global().async(flags: .barrier) { log.log("ran") }
        """)
        assertFinished(run)
        XCTAssertTrue(run.events.contains { $0.kind == .warning && $0.text.contains("ignored on a global queue") })
    }

    func testTeachingBarrierHelperAssertsOnAGlobalQueue() {
        let run = simulate("""
        Concurrency101.GCD.runExclusiveWrite(on: DispatchQueue.global()) { log.log("write") }
        """)
        guard case .crashed(let message, let line, _) = run.outcome else {
            return XCTFail("expected the DEBUG assert, got \(run.outcome)")
        }
        XCTAssertTrue(message.contains("barriers on DispatchQueue.global()"), message)
        XCTAssertEqual(line, 1)
    }

    func testUnbalancedLeaveCrashesLikeDispatchDoes() {
        let run = simulate("""
        let g = DispatchGroup()
        g.leave()
        """)
        guard case .crashed(let message, let line, let thread) = run.outcome else {
            return XCTFail("expected a crash, got \(run.outcome)")
        }
        XCTAssertTrue(message.contains("Unbalanced call to dispatch_group_leave()"), message)
        XCTAssertEqual(line, 2)
        XCTAssertEqual(thread, "main")
    }

    func testSemaphoreNeverSignalledOnAWorkerIsAHangNotAFrozenUI() {
        let run = simulate("""
        let gate = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            gate.wait()
            log.log("never")
        }
        log.log("main is free")
        """)
        guard let s = stall(run) else { return }
        XCTAssertTrue(s.headline.hasPrefix("Hang"), s.headline)
        XCTAssertFalse(s.mainThreadFrozen)
        XCTAssertEqual(lines(run), ["main is free"])
    }

    func testDispatchPrecondition() {
        let run = simulate("""
        DispatchQueue.global().async {
            dispatchPrecondition(condition: .onQueue(.main))
        }
        """)
        guard case .crashed(let message, _, _) = run.outcome else {
            return XCTFail("expected a crash, got \(run.outcome)")
        }
        XCTAssertTrue(message.contains("dispatchPrecondition failed"), message)
    }

    func testConcurrentPerformBlocksTheCallerUntilEveryIterationRan() {
        let run = simulate("""
        var hits = 0
        let lock = DispatchQueue(label: "lock")
        DispatchQueue.concurrentPerform(iterations: 6) { i in
            lock.sync { hits += 1 }
        }
        log.log("hits \\(hits)")
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["hits 6"])
        XCTAssertTrue(run.notes.isEmpty, "\(run.notes)")
    }

    func testAsyncAfterOrderingFollowsTheVirtualClock() {
        let run = simulate("""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { log.log("late") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { log.log("early") }
        """)
        XCTAssertEqual(lines(run), ["early", "late"])
        XCTAssertEqual(run.endTime, 0.3, accuracy: 0.01)
    }

    func testInfiniteLoopStopsAtTheStepLimit() {
        let run = Simulator.run("while true {}", configuration: SimConfiguration(maxSteps: 50_000))
        XCTAssertEqual(run.outcome, .stepLimit)
    }

    func testTimelineShowsTheBlockedMainThread() {
        let run = simulate("DispatchQueue.main.sync { }")
        let main = run.lanes.first { $0.kind == .main }
        XCTAssertEqual(main?.segments.last?.isBlocked, true)
        XCTAssertEqual(main?.segments.last?.unfinished, true)
        XCTAssertEqual(main?.segments.last?.label, "DispatchQueue.main.sync")
    }
}
