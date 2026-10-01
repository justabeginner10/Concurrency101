import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: serial `DispatchQueue` FIFO and `queue.sync` from another queue.
final class SerialLaneTests: XCTestCase {
    func testSerialLanePreservesSubmissionOrder() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.serial.fifo")
        let count = 25
        let done = expectation(description: "all serial items")
        done.expectedFulfillmentCount = count
        var order: [Int] = []

        for index in 0..<count {
            Concurrency101.GCD.runOnLane(lane) {
                order.append(index)
                done.fulfill()
            }
        }

        wait(for: [done], timeout: TestSupport.timeout)
        XCTAssertEqual(order, Array(0..<count), "a serial queue runs items one at a time in FIFO order")
    }

    func testMakePrivateSerialLaneUsesTheGivenLabel() {
        let label = "com.concurrency101.tests.named-serial"
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: label)
        XCTAssertEqual(lane.label, label)
    }

    func testBlockingSyncOnSerialLaneFromThisThreadWaitsUntilFinished() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.serial.sync")
        let delay: TimeInterval = 0.08
        var flag = false
        let started = Date()

        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: lane) {
            Thread.sleep(forTimeInterval: delay)
            flag = true
        }

        XCTAssertTrue(flag, "sync does not return until work has finished")
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), delay - 0.01)
    }

    func testSerialLaneRunsTheNextItemOnlyAfterTheCurrentItemReturns() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.serial.no-overlap")
        let done = expectation(description: "both items")
        done.expectedFulfillmentCount = 2
        let order = Locked<[String]>([])

        Concurrency101.GCD.runOnLane(lane) {
            order.mutate { $0.append("first-start") }
            Thread.sleep(forTimeInterval: 0.1)
            order.mutate { $0.append("first-end") }
            done.fulfill()
        }
        Concurrency101.GCD.runOnLane(lane) {
            order.mutate { $0.append("second") }
            done.fulfill()
        }

        wait(for: [done], timeout: TestSupport.timeout)
        XCTAssertEqual(order.read(), ["first-start", "first-end", "second"])
    }

    func testPrivateSerialLaneStoresTheRequestedQoS() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(
            label: "tests.serial.qos",
            qos: .userInitiated
        )
        XCTAssertEqual(lane.qos, .userInitiated)
    }
}
