import Dispatch
import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: the semaphore-around-Task anti-pattern.
///
/// Never park the main thread waiting for MainActor work.
final class ModernBlockingTests: XCTestCase {
    func testParkThisThreadUntilTaskFinishesOnABackgroundThread() {
        let ran = expectation(description: "detached work finished")
        DispatchQueue.global(qos: .userInitiated).async {
            Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
                try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
            }
            ran.fulfill()
        }
        wait(for: [ran], timeout: TestSupport.timeout)
    }
}
