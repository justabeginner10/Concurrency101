import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: `actor` isolation and reentrancy.
final class ModernExclusiveStateTests: XCTestCase {
    func testSerialIncrementsAreNotLost() async {
        let counter = Concurrency101.Modern.ExclusiveState(0)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    await counter.modify { $0 += 1 }
                }
            }
        }
        let value = await counter.snapshot()
        XCTAssertEqual(value, 200)
    }

    func testReadAwaitWriteCanLoseAnInterleavedIncrement() async {
        let counter = Concurrency101.Modern.ExclusiveState(0)
        let startedSleep = expectation(description: "first task suspended")
        let finished = expectation(description: "both writers done")
        finished.expectedFulfillmentCount = 2

        Task {
            await counter.readAwaitWrite { current in
                startedSleep.fulfill()
                try? await Concurrency101.Modern.pauseThisTask(for: 0.12)
                return current + 1
            }
            finished.fulfill()
        }

        await fulfillment(of: [startedSleep], timeout: TestSupport.timeout)

        Task {
            await counter.modify { $0 += 1 }
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: TestSupport.timeout)
        let value = await counter.snapshot()
        XCTAssertEqual(
            value,
            1,
            "reentrancy: the delayed write stomps the increment that ran during await"
        )
    }
}
