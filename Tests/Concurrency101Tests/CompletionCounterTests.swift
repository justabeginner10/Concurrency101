import Dispatch
import XCTest
@testable import Concurrency101

/// GCD under test: `DispatchGroup.enter` / `leave` / `notify` / `wait`.
final class CompletionCounterTests: XCTestCase {
    func testBalancedBeginEndNotifiesOnChosenQueue() {
        let counter = Concurrency101.GCD.CompletionCounter()
        let finishLane = Concurrency101.GCD.makePrivateSerialLane(label: "tests.counter.finish")
        let finished = expectation(description: "notify after balance")

        counter.beginOne()
        counter.beginOne()
        counter.whenAllHaveEnded(on: finishLane) {
            dispatchPrecondition(condition: .onQueue(finishLane))
            finished.fulfill()
        }

        Concurrency101.GCD.runOnLane(Concurrency101.GCD.makePrivateSerialLane(label: "tests.counter.a")) {
            counter.endOne()
        }
        Concurrency101.GCD.runOnLane(Concurrency101.GCD.makePrivateSerialLane(label: "tests.counter.b")) {
            counter.endOne()
        }

        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testMissingEndOneMeansNotifyDoesNotFire() {
        let counter = Concurrency101.GCD.CompletionCounter()
        let shouldNotRun = expectation(description: "notify must not fire")
        shouldNotRun.isInverted = true

        counter.beginOne()
        counter.whenAllHaveEnded(on: Concurrency101.GCD.makePrivateSerialLane(label: "tests.counter.silent")) {
            shouldNotRun.fulfill()
        }

        wait(for: [shouldNotRun], timeout: 0.2)
    }

    func testWhenAllHaveEndedOnAlreadyBalancedCounterFires() {
        let counter = Concurrency101.GCD.CompletionCounter()
        let finished = expectation(description: "already zero")

        counter.whenAllHaveEnded(on: Concurrency101.GCD.makePrivateSerialLane(label: "tests.counter.zero")) {
            finished.fulfill()
        }

        wait(for: [finished], timeout: TestSupport.timeout)
    }

    func testDeferEndOneOnEveryPath() {
        let counter = Concurrency101.GCD.CompletionCounter()
        let finished = expectation(description: "defer leave")

        counter.beginOne()
        counter.whenAllHaveEnded(on: Concurrency101.GCD.makePrivateSerialLane(label: "tests.counter.defer")) {
            finished.fulfill()
        }

        func fakeCallback(succeed: Bool) {
            defer { counter.endOne() }
            XCTAssertTrue(succeed)
        }
        fakeCallback(succeed: true)

        wait(for: [finished], timeout: TestSupport.timeout)
    }
}
