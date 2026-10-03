import XCTest
@testable import Concurrency101

/// Swift Concurrency under test: `withCheckedContinuation`.
final class ModernBridgeTests: XCTestCase {
    func testWaitForCallbackResumesWithValue() async {
        let value = await Concurrency101.Modern.waitForCallback { continuation in
            Concurrency101.GCD.runUserRequestedWork {
                continuation.resume(returning: 42)
            }
        }
        XCTAssertEqual(value, 42)
    }

    func testWaitForThrowingCallbackCanFail() async {
        struct DemoError: Error {}
        do {
            let _: Int = try await Concurrency101.Modern.waitForThrowingCallback { continuation in
                continuation.resume(throwing: DemoError())
            }
            XCTFail("should have thrown")
        } catch is DemoError {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
