import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `DispatchWorkItem` cooperative cancellation.
final class WorkItemTests: XCTestCase {
    func testCancelBeforeEnqueueMeansWorkDoesNotRun() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.work.cancel-before")
        let ran = Locked(false)
        let item = Concurrency101.GCD.makeCancellableWork {
            ran.write(true)
        }

        item.cancel()
        lane.async(execute: item)

        let settled = expectation(description: "give the queue a chance")
        Concurrency101.GCD.runOnLane(lane) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: TestSupport.timeout)
        XCTAssertFalse(ran.read(), "a cancelled work item that has not started should not run")
        XCTAssertTrue(item.isCancelled)
    }

    func testCancelDoesNotStopWorkThatIsAlreadyRunning() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.work.cancel-during")
        let started = expectation(description: "body started")
        let finished = expectation(description: "body finished despite cancel")
        let item = Concurrency101.GCD.makeCancellableWork {
            started.fulfill()
            Thread.sleep(forTimeInterval: 0.12)
            finished.fulfill()
        }

        lane.async(execute: item)
        wait(for: [started], timeout: TestSupport.timeout)
        item.cancel()
        wait(for: [finished], timeout: TestSupport.timeout)
        XCTAssertTrue(item.isCancelled)
    }

    func testWorkItemNotifyRunsAfterTheBlock() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.work.notify")
        let notified = expectation(description: "work item notify")
        let order = Locked<[String]>([])
        let item = Concurrency101.GCD.makeCancellableWork {
            order.mutate { $0.append("work") }
        }
        item.notify(queue: lane) {
            order.mutate { $0.append("notify") }
            notified.fulfill()
        }
        lane.async(execute: item)
        wait(for: [notified], timeout: TestSupport.timeout)
        XCTAssertEqual(order.read(), ["work", "notify"])
    }

    func testUncancelledWorkItemRuns() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.work.runs")
        let ran = expectation(description: "body ran")
        let item = Concurrency101.GCD.makeCancellableWork {
            ran.fulfill()
        }
        XCTAssertFalse(item.isCancelled)
        lane.async(execute: item)
        wait(for: [ran], timeout: TestSupport.timeout)
    }
}
