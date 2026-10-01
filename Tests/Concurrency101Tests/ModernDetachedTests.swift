import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: `Task { }` inherits isolation; `Task.detached` does not.
final class ModernDetachedTests: XCTestCase {
    @MainActor
    func testDetachedLeavesTheMainActor() async {
        let detachedWasMain = Locked(true)
        let task = Concurrency101.Modern.runDetachedFromCaller {
            detachedWasMain.write(Thread.isMainThread)
        }
        await task.value
        XCTAssertFalse(
            detachedWasMain.read(),
            "Task.detached must not inherit @MainActor from this test method"
        )
    }

    @MainActor
    func testUnstructuredUpdateUIRunsOnMainEvenWhenStartedFromMain() async {
        let wasMain = Locked(false)
        let task = Concurrency101.Modern.updateUI {
            wasMain.write(Thread.isMainThread)
        }
        await task.value
        XCTAssertTrue(wasMain.read())
    }
}
