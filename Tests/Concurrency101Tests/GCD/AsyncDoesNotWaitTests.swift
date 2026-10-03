import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `queue.async` without waiting (`async` vs `sync`).
final class AsyncDoesNotWaitTests: XCTestCase {
    func testRunUserRequestedWorkLetsTheNextLineRunFirst() {
        let finished = expectation(description: "work ran")
        let gate = DispatchSemaphore(value: 0)
        var nextLineAlreadyRan = false

        Concurrency101.GCD.runUserRequestedWork {
            gate.wait()
            finished.fulfill()
        }

        nextLineAlreadyRan = true
        XCTAssertTrue(nextLineAlreadyRan)
        gate.signal()
        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testRunOnLaneLetsTheNextLineRunFirst() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.async-does-not-wait")
        let finished = expectation(description: "lane work")
        let gate = DispatchSemaphore(value: 0)
        var nextLineAlreadyRan = false

        Concurrency101.GCD.runOnLane(lane) {
            gate.wait()
            finished.fulfill()
        }

        nextLineAlreadyRan = true
        XCTAssertTrue(nextLineAlreadyRan)
        gate.signal()
        wait(for: [finished], timeout: TestSupport.timeout)
    }
}
