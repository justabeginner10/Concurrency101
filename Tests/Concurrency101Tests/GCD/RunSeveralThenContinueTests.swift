import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `DispatchGroup` + `async(group:)` + `notify`.
final class RunSeveralThenContinueTests: XCTestCase {
    func testFinishRunsAfterAllJobsAndDefaultsToMain() {
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "tests.group.jobs")
        let jobsDone = Locked(0)
        let finished = expectation(description: "notify")

        Concurrency101.GCD.runSeveralThenContinue(
            on: lane,
            jobs: [
                { jobsDone.mutate { $0 += 1 } },
                { jobsDone.mutate { $0 += 1 } },
                { jobsDone.mutate { $0 += 1 } },
            ],
            then: {
                XCTAssertEqual(jobsDone.read(), 3)
                dispatchPrecondition(condition: .onQueue(.main))
                finished.fulfill()
            },
            finishOn: .main
        )

        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testFinishOnRespectsACustomLane() {
        let jobs = Concurrency101.GCD.makePrivateSerialLane(label: "tests.group.jobs-serial")
        let finishLane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.group.finish")
        let finished = expectation(description: "custom finish queue")

        Concurrency101.GCD.runSeveralThenContinue(
            on: jobs,
            jobs: [{ /* empty */ }, { /* empty */ }],
            then: {
                dispatchPrecondition(condition: .onQueue(finishLane))
                finished.fulfill()
            },
            finishOn: finishLane
        )

        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testEmptyJobsStillInvokesFinish() {
        let finished = expectation(description: "empty group notify")

        Concurrency101.GCD.runSeveralThenContinue(
            jobs: [],
            then: { finished.fulfill() }
        )

        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testCallerDoesNotWaitForJobs() {
        let gate = DispatchSemaphore(value: 0)
        let finished = expectation(description: "slow job finished")
        var continued = false

        Concurrency101.GCD.runSeveralThenContinue(
            jobs: [
                {
                    gate.wait()
                    finished.fulfill()
                }
            ],
            then: { },
            finishOn: Concurrency101.GCD.makePrivateSerialLane(label: "tests.group.unused-finish")
        )

        continued = true
        XCTAssertTrue(continued)
        gate.signal()
        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testDefaultJobQueueIsNotTheMainQueue() {
        let jobRan = expectation(description: "job")
        let finishLane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.group.not-main-finish")

        Concurrency101.GCD.runSeveralThenContinue(
            jobs: [
                {
                    XCTAssertFalse(Thread.isMainThread)
                    jobRan.fulfill()
                }
            ],
            then: { },
            finishOn: finishLane
        )

        wait(for: [jobRan], timeout: TestSupport.timeout)
    }
}
