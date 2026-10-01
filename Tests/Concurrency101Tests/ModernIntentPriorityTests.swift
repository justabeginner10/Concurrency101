import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: `Task(priority:)` returns immediately.
final class ModernIntentPriorityTests: XCTestCase {
    func testRunUserRequestedWorkDoesNotWait() async {
        let ran = expectation(description: "user-initiated task")
        let started = Locked(false)

        Concurrency101.Modern.runUserRequestedWork {
            try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
            started.write(true)
            ran.fulfill()
        }

        XCTAssertFalse(started.read(), "runUserRequestedWork must return before the body finishes")
        await fulfillment(of: [ran], timeout: TestSupport.timeout)
        XCTAssertTrue(started.read())
    }

    func testPriorityHelpersReturnImmediately() async {
        let hops: [(String, (@escaping @Sendable () async -> Void) -> Task<Void, Never>)] = [
            ("immediate", Concurrency101.Modern.runForImmediateUI),
            ("user", Concurrency101.Modern.runUserRequestedWork),
            ("maintenance", Concurrency101.Modern.runMaintenanceWork),
            ("not-waiting", Concurrency101.Modern.runWhenUserIsNotWaiting),
        ]

        for (name, hop) in hops {
            let ran = expectation(description: name)
            hop {
                ran.fulfill()
            }
            await fulfillment(of: [ran], timeout: TestSupport.timeout)
        }
    }
}
