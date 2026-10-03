import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `DispatchQueue.global(qos:).async`.
///
/// QoS is intent, not a start-time guarantee. These tests only prove
/// “returns immediately” and “does not run on the main queue.”
final class IntentQoSTests: XCTestCase {
    func testRunForImmediateUIDoesNotWaitAndIsNotMain() {
        assertGlobalHopDoesNotWait(Concurrency101.GCD.runForImmediateUI)
    }

    func testRunUserRequestedWorkDoesNotWaitAndIsNotMain() {
        assertGlobalHopDoesNotWait(Concurrency101.GCD.runUserRequestedWork)
    }

    func testRunMaintenanceWorkDoesNotWaitAndIsNotMain() {
        assertGlobalHopDoesNotWait(Concurrency101.GCD.runMaintenanceWork)
    }

    func testRunWhenUserIsNotWaitingDoesNotWaitAndIsNotMain() {
        assertGlobalHopDoesNotWait(Concurrency101.GCD.runWhenUserIsNotWaiting)
    }

    /// Holds the submitted work until the caller has proven it already continued.
    private func assertGlobalHopDoesNotWait(_ hop: (@escaping () -> Void) -> Void) {
        let ran = expectation(description: "hop finished")
        let gate = DispatchSemaphore(value: 0)
        let continuedBeforeWork = Locked(false)

        hop {
            gate.wait()
            XCTAssertFalse(Thread.isMainThread, "global QoS hops are not the main queue")
            ran.fulfill()
        }

        continuedBeforeWork.write(true)
        XCTAssertTrue(
            continuedBeforeWork.read(),
            "async submission must return before the body runs"
        )
        gate.signal()
        wait(for: [ran], timeout: TestSupport.timeout)
    }
}
