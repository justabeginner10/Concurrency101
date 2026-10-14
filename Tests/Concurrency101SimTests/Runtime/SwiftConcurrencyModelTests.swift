import XCTest
@testable import Concurrency101Sim

final class SwiftConcurrencyModelTests: XCTestCase {
    func testTaskInheritsTheMainActorAndDetachedDoesNot() {
        let run = simulate("""
        Task { log.log("task main: \\(Thread.isMainThread)") }
        Task.detached { log.log("detached main: \\(Thread.isMainThread)") }
        """)
        assertFinished(run)
        XCTAssertEqual(event("task main", in: run)?.text, "task main: true")
        XCTAssertEqual(event("detached main", in: run)?.text, "detached main: false")
    }

    func testMainActorRunHopsToMainAndBack() {
        let run = simulate("""
        Task.detached {
            log.log("before \\(Thread.isMainThread)")
            await MainActor.run { log.log("inside \\(Thread.isMainThread)") }
            log.log("after \\(Thread.isMainThread)")
        }
        """)
        XCTAssertEqual(lines(run), ["before false", "inside true", "after false"])
    }

    func testActorMethodNeedsAwaitFromOutside() {
        let run = simulate("""
        actor Counter {
            var value = 0
            func increment() { value += 1 }
        }
        let c = Counter()
        Task.detached {
            c.increment()
        }
        """)
        guard case .crashed(let message, let line, _) = run.outcome else {
            return XCTFail("expected an isolation error, got \(run.outcome)")
        }
        XCTAssertTrue(message.contains("needs 'await'"), message)
        XCTAssertEqual(line, 7)
    }

    func testReadingActorStateFromOutsideNeedsAwait() {
        let run = simulate("""
        actor Counter { var value = 0 }
        let c = Counter()
        Task { log.log("\\(c.value)") }
        """)
        guard case .crashed(let message, _, _) = run.outcome else {
            return XCTFail("expected an isolation error, got \(run.outcome)")
        }
        XCTAssertTrue(message.contains("without 'await'"), message)
    }

    func testActorSerializesItsMethodsEvenWhenTheyBlock() {
        let run = simulate("""
        actor Slow {
            func work(_ name: String) {
                log.log("\\(name) start")
                Thread.sleep(forTimeInterval: 0.1)
                log.log("\\(name) end")
            }
        }
        let s = Slow()
        Task.detached { await s.work("a") }
        Task.detached { await s.work("b") }
        """)
        assertFinished(run)
        let l = lines(run)
        XCTAssertEqual(l.count, 4)
        XCTAssertTrue(l[0].hasSuffix("start") && l[1].hasSuffix("end") && l[2].hasSuffix("start") && l[3].hasSuffix("end"), "\(l)")
        XCTAssertEqual(run.endTime, 0.2, accuracy: 0.02)
    }

    func testBlockingInsideTasksStarvesTheCooperativePool() {
        // Unlike GCD, the cooperative pool never grows: eight tasks that
        // each block for 0.1s on two cores take 0.4s.
        let run = simulate("""
        for i in 0..<8 {
            Task.detached { Thread.sleep(forTimeInterval: 0.1) }
        }
        """, cores: 2)
        assertFinished(run)
        XCTAssertEqual(run.endTime, 0.4, accuracy: 0.03)
        XCTAssertEqual(run.lanes.filter { $0.kind == .cooperative }.count, 2)
    }

    func testAwaitingSleepDoesNotHoldAThread() {
        let run = simulate("""
        for i in 0..<8 {
            Task.detached { try? await Task.sleep(for: .seconds(0.1)) }
        }
        """, cores: 2)
        assertFinished(run)
        XCTAssertEqual(run.endTime, 0.1, accuracy: 0.02)
    }

    func testPoolStarvationDeadlockIsDiagnosed() {
        let run = simulate("""
        let gate = DispatchSemaphore(value: 0)
        for i in 0..<2 {
            Task.detached { gate.wait() }
        }
        Task.detached { gate.signal(); gate.signal() }
        """, cores: 2)
        guard let s = stall(run) else { return }
        XCTAssertTrue(s.headline.contains("starvation"), s.headline)
    }

    func testCancellationReachesTaskGroupChildren() {
        let run = simulate("""
        let parent = Task {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<3 {
                    group.addTask {
                        do {
                            try await Task.sleep(for: .seconds(5))
                        } catch {
                            log.log("child cancelled")
                        }
                    }
                }
            }
            log.log("group done")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { parent.cancel() }
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run).filter { $0 == "child cancelled" }.count, 3)
        XCTAssertEqual(lines(run).last, "group done")
        XCTAssertLessThan(run.endTime, 0.2)
    }

    func testForAwaitOverATaskGroupCollectsResults() {
        let run = simulate("""
        Task {
            let total = await withTaskGroup(of: Int.self) { group in
                for i in 1...4 {
                    group.addTask { i * 10 }
                }
                var sum = 0
                for await value in group {
                    sum += value
                }
                return sum
            }
            log.log("sum \\(total)")
        }
        """)
        XCTAssertEqual(lines(run), ["sum 100"])
    }

    func testTaskValueAndThrowingTasks() {
        let run = simulate("""
        enum Oops: Error { case bad }
        let ok = Task { () -> Int in 7 }
        let failing = Task { () throws -> Int in throw Oops.bad }
        Task {
            log.log("ok \\(await ok.value)")
            do {
                _ = try await failing.value
            } catch is Oops {
                log.log("caught Oops")
            }
        }
        """)
        XCTAssertEqual(lines(run), ["ok 7", "caught Oops"])
    }

    func testCheckCancellationThrows() {
        let run = simulate("""
        let t = Task {
            do {
                try Task.checkCancellation()
                log.log("not cancelled")
            } catch is CancellationError {
                log.log("cancelled")
            }
        }
        t.cancel()
        """)
        XCTAssertEqual(lines(run), ["cancelled"])
    }

    func testResumingAContinuationTwiceCrashes() {
        let run = simulate("""
        Task {
            let v = await withCheckedContinuation { c in
                c.resume(returning: 1)
                c.resume(returning: 2)
            }
        }
        """)
        guard case .crashed(let message, _, _) = run.outcome else {
            return XCTFail("expected a crash, got \(run.outcome)")
        }
        XCTAssertTrue(message.contains("more than once"), message)
    }

    func testForgettingToResumeAContinuationLeaksTheTask() {
        let run = simulate("""
        Task {
            await withCheckedContinuation { c in
                log.log("forgot to resume")
            }
            log.log("never")
        }
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["forgot to resume"])
        XCTAssertTrue(run.notes.contains { $0.text.contains("never resumed") })
    }

    func testYieldLetsOtherWorkRunOnTheMainActor() {
        let run = simulate("""
        Task {
            log.log("a1")
            await Task.yield()
            log.log("a2")
        }
        Task {
            log.log("b1")
        }
        """)
        XCTAssertEqual(lines(run), ["a1", "b1", "a2"])
    }

    func testNonisolatedAsyncFunctionLeavesTheMainActor() {
        let run = simulate("""
        func load() async -> Bool {
            Thread.isMainThread
        }
        Task {
            let wasMain = await load()
            log.log("load ran on main: \\(wasMain), back on main: \\(Thread.isMainThread)")
        }
        """)
        XCTAssertEqual(lines(run), ["load ran on main: false, back on main: true"])
    }

    func testMainActorFunctionCalledFromDetachedTaskHops() {
        let run = simulate("""
        @MainActor func render() { log.log("render on main: \\(Thread.isMainThread)") }
        Task.detached { await render() }
        """)
        XCTAssertEqual(lines(run), ["render on main: true"])
    }
}
