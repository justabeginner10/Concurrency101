import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `queue.async(flags: .barrier)` on a *custom* concurrent queue.
final class BarrierTests: XCTestCase {
    func testExclusiveWriteWaitsForInFlightReadsThenBlocksLaterReads() {
        let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "tests.barrier")
        let events = Locked<[String]>([])
        let done = expectation(description: "barrier sequence")
        done.expectedFulfillmentCount = 4

        func log(_ name: String) {
            events.mutate { $0.append(name) }
        }

        Concurrency101.GCD.runOnLane(lane) {
            log("read-start-a")
            Thread.sleep(forTimeInterval: 0.08)
            log("read-end-a")
            done.fulfill()
        }
        Concurrency101.GCD.runOnLane(lane) {
            log("read-start-b")
            Thread.sleep(forTimeInterval: 0.08)
            log("read-end-b")
            done.fulfill()
        }
        Concurrency101.GCD.runExclusiveWrite(on: lane) {
            log("write")
            done.fulfill()
        }
        Concurrency101.GCD.runOnLane(lane) {
            log("after")
            done.fulfill()
        }

        wait(for: [done], timeout: TestSupport.timeout)

        let recorded = events.read()
        let writeIndex = recorded.firstIndex(of: "write")
        let afterIndex = recorded.firstIndex(of: "after")
        let endA = recorded.firstIndex(of: "read-end-a")
        let endB = recorded.firstIndex(of: "read-end-b")

        XCTAssertNotNil(writeIndex)
        XCTAssertNotNil(afterIndex)
        XCTAssertNotNil(endA)
        XCTAssertNotNil(endB)

        guard let writeIndex, let afterIndex, let endA, let endB else { return }

        XCTAssertGreaterThan(
            writeIndex,
            endA,
            "barrier waits for in-flight items submitted before it"
        )
        XCTAssertGreaterThan(writeIndex, endB)
        XCTAssertGreaterThan(
            afterIndex,
            writeIndex,
            "work submitted after a barrier waits for the barrier"
        )
        XCTAssertFalse(recorded.contains("after") && afterIndex < writeIndex)
    }

    func testGlobalQueuesAreIdentifiedForTheDEBUGBarrierAssert() {
        XCTAssertTrue(GlobalQueueIdentity.matches(.global(qos: .userInitiated)))
        XCTAssertTrue(GlobalQueueIdentity.matches(.global(qos: .background)))
        XCTAssertFalse(GlobalQueueIdentity.matches(.main))
        XCTAssertFalse(
            GlobalQueueIdentity.matches(
                Concurrency101.GCD.makeSharedConcurrentLane(label: "tests.not-global")
            )
        )
    }
}
