import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: concurrent `DispatchQueue` — items may overlap.
final class ConcurrentLaneTests: XCTestCase {
    func testConcurrentLaneAllowsOverlap() {
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "tests.concurrent.overlap")
        let firstFinished = expectation(description: "first item finished")
        let secondRan = expectation(description: "second item ran while first waited")
        let gate = DispatchSemaphore(value: 0)

        Concurrency101.GCD.runOnLane(lane) {
            gate.wait()
            firstFinished.fulfill()
        }
        Concurrency101.GCD.runOnLane(lane) {
            secondRan.fulfill()
            gate.signal()
        }

        wait(for: [secondRan, firstFinished], timeout: TestSupport.timeout)
    }

    func testMakeSharedConcurrentLaneUsesTheGivenLabel() {
        let label = "com.concurrency101.tests.named-concurrent"
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: label)
        XCTAssertEqual(lane.label, label)
    }
}
