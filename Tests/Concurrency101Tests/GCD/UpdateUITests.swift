import XCTest
@testable import Concurrency101

/// GCD under test: `DispatchQueue.main.async` and `asyncAfter`.
final class UpdateUITests: XCTestCase {
    func testUpdateUIReturnsImmediatelyAndThenRunsOnMain() {
        let ran = expectation(description: "updateUI body")
        let executed = Locked(false)

        Concurrency101.GCD.updateUI {
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertTrue(Thread.isMainThread)
            executed.write(true)
            ran.fulfill()
        }

        XCTAssertFalse(
            executed.read(),
            "updateUI is async: the body must not have run before this line"
        )
        wait(for: [ran], timeout: TestSupport.timeout)
        XCTAssertTrue(executed.read())
    }

    func testUpdateUIFromAGlobalHopStillRunsOnMain() {
        let ran = expectation(description: "main after background")

        Concurrency101.GCD.runUserRequestedWork {
            XCTAssertFalse(Thread.isMainThread)
            Concurrency101.GCD.updateUI {
                XCTAssertTrue(Thread.isMainThread)
                ran.fulfill()
            }
        }

        wait(for: [ran], timeout: TestSupport.timeout)
    }

    func testUpdateUIAfterDoesNotRunEarly() {
        let ran = expectation(description: "delayed updateUI")
        let delay: TimeInterval = 0.15
        let started = Date()

        Concurrency101.GCD.updateUI(after: delay) {
            let elapsed = Date().timeIntervalSince(started)
            XCTAssertGreaterThanOrEqual(
                elapsed,
                delay - 0.02,
                "asyncAfter deadline is eligibility; body should not run early"
            )
            XCTAssertTrue(Thread.isMainThread)
            ran.fulfill()
        }

        wait(for: [ran], timeout: TestSupport.timeout)
    }

    func testUpdateUIAfterReturnsImmediately() {
        let ran = expectation(description: "later")
        let started = Locked(false)

        Concurrency101.GCD.updateUI(after: 0.05) {
            started.write(true)
            ran.fulfill()
        }

        XCTAssertFalse(started.read())
        wait(for: [ran], timeout: TestSupport.timeout)
        XCTAssertTrue(started.read())
    }
}
