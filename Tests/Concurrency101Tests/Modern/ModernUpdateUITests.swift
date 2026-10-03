import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: `Task { @MainActor in }` and `MainActor.run`.
final class ModernUpdateUITests: XCTestCase {
    func testUpdateUIReturnsImmediatelyAndThenRunsOnMain() async {
        let ran = expectation(description: "updateUI body")
        let executed = Locked(false)

        Concurrency101.Modern.updateUI {
            XCTAssertTrue(Thread.isMainThread)
            executed.write(true)
            ran.fulfill()
        }

        XCTAssertFalse(
            executed.read(),
            "updateUI is unstructured: the body must not have run before this line"
        )
        await fulfillment(of: [ran], timeout: TestSupport.timeout)
        XCTAssertTrue(executed.read())
    }

    func testWaitForUIRunsOnMainAndCallerResumesAfter() async {
        let before = Locked(true)
        await Concurrency101.Modern.waitForUI {
            XCTAssertTrue(Thread.isMainThread)
            before.write(false)
        }
        XCTAssertFalse(before.read(), "waitForUI must finish before this line")
    }

    func testUpdateUIAfterDoesNotRunEarly() async {
        let ran = expectation(description: "delayed updateUI")
        let delay: TimeInterval = 0.15
        let started = Date()

        Concurrency101.Modern.updateUI(after: delay) {
            let elapsed = Date().timeIntervalSince(started)
            XCTAssertGreaterThanOrEqual(elapsed, delay - 0.04)
            XCTAssertTrue(Thread.isMainThread)
            ran.fulfill()
        }

        await fulfillment(of: [ran], timeout: TestSupport.timeout)
    }
}
