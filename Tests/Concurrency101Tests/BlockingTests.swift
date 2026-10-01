import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `queue.sync` and `DispatchGroup.wait`.
///
/// Never `sync` the main queue from the main thread in these tests.
final class BlockingTests: XCTestCase {
    func testBlockThisThreadUntilFinishedOnAPrivateLane() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.blocking.sync")
        let seen = Locked(0)

        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: lane) {
            seen.write(7)
        }

        XCTAssertEqual(seen.read(), 7)
    }

    func testBlockThisThreadUntilAllJobsEndSucceedsWhenBalanced() {
        let counter = Concurrency101.GCD.CompletionCounter()
        let worker = Concurrency101.GCD.makePrivateSerialLane(label: "tests.blocking.wait-success")

        counter.beginOne()
        Concurrency101.GCD.runOnLane(worker) {
            counter.endOne()
        }

        let outcome = Concurrency101.GCD.Blocking.blockThisThreadUntilAllJobsEnd(
            counter,
            timeout: .now() + TestSupport.timeout
        )
        XCTAssertEqual(outcome, .success)
    }

    func testBlockThisThreadUntilAllJobsEndTimesOutWhenStillInFlight() {
        let counter = Concurrency101.GCD.CompletionCounter()
        counter.beginOne()

        let outcome = Concurrency101.GCD.Blocking.blockThisThreadUntilAllJobsEnd(
            counter,
            timeout: .now() + 0.1
        )
        XCTAssertEqual(outcome, .timedOut)

        // Balance the group so the process does not keep a stray waiter.
        counter.endOne()
    }

    func testSyncOntoADifferentQueueFromMainDoesNotDeadlock() {
        let lane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.blocking.not-main")
        var ran = false
        Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: lane) {
            ran = true
        }
        XCTAssertTrue(ran)
    }
}
