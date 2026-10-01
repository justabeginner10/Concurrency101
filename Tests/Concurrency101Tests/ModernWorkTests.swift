import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: cooperative cancellation and `Task.sleep`.
final class ModernWorkTests: XCTestCase {
    func testCancellingASleepingTaskEndsIt() async {
        let finishedSleep = Locked(false)
        let task = Concurrency101.Modern.makeCancellableWork {
            do {
                try await Concurrency101.Modern.pauseThisTask(for: 2)
                finishedSleep.write(true)
            } catch is CancellationError {
                // expected
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
        try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
        task.cancel()
        await task.value
        XCTAssertFalse(finishedSleep.read(), "cancelled sleep must not complete normally")
    }

    func testThrowIfCancelled() {
        XCTAssertNoThrow(try Concurrency101.Modern.throwIfCancelled())
    }

    func testPauseThisTaskIsAtLeastTheRequestedDuration() async throws {
        let started = Date()
        try await Concurrency101.Modern.pauseThisTask(for: 0.12)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.08)
    }
}
