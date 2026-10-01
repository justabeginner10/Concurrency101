import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: `withTaskGroup` and `async let`.
final class ModernStructuredTests: XCTestCase {
    func testRunSeveralThenContinueWaitsForEveryJobThenFinish() async {
        let events = Locked<[String]>([])
        await Concurrency101.Modern.runSeveralThenContinue(
            jobs: [
                {
                    try? await Concurrency101.Modern.pauseThisTask(for: 0.08)
                    events.mutate { $0.append("a") }
                },
                {
                    try? await Concurrency101.Modern.pauseThisTask(for: 0.02)
                    events.mutate { $0.append("b") }
                },
            ],
            then: {
                events.mutate { $0.append("finish") }
            }
        )
        let snapshot = events.read()
        XCTAssertEqual(snapshot.last, "finish")
        XCTAssertEqual(Set(snapshot), ["a", "b", "finish"])
    }

    func testRunTwoAtOnceReturnsBothInArgumentOrder() async {
        let (first, second) = await Concurrency101.Modern.runTwoAtOnce(
            {
                try? await Concurrency101.Modern.pauseThisTask(for: 0.05)
                return "slow"
            },
            { "fast" }
        )
        XCTAssertEqual(first, "slow")
        XCTAssertEqual(second, "fast")
    }
}
