import XCTest
@testable import Concurrency101Sim

/// Mistakes the real compiler rejects should be rejected here too, with a
/// message that says what to do.
final class DiagnosticsTests: XCTestCase {
    private func assertError(_ source: String, contains text: String, file: StaticString = #filePath, line: UInt = #line) {
        let errors = compileErrors(source)
        XCTAssertTrue(errors.contains { $0.contains(text) }, "expected an error containing '\(text)', got \(errors)", file: file, line: line)
    }

    func testAwaitAtTopLevelExplainsTheButtonAction() {
        assertError("try? await Task.sleep(for: .seconds(1))", contains: "Wrap async work in Task")
    }

    func testAwaitInsideADispatchBlock() {
        assertError("""
        DispatchQueue.global().async {
            try? await Task.sleep(for: .seconds(1))
        }
        """, contains: "DispatchQueue block is synchronous")
    }

    func testMissingAwaitOnAnAsyncCall() {
        assertError("""
        Task {
            try? Task.sleep(for: .seconds(1))
        }
        """, contains: "mark the call with 'await'")
    }

    func testMissingTryOnAThrowingCall() {
        assertError("""
        Task {
            await Task.sleep(for: .seconds(1))
        }
        """, contains: "mark the call with 'try'")
    }

    func testTryOutsideDoCatchInSynchronousCode() {
        assertError("""
        func risky() throws {}
        try risky()
        """, contains: "can't throw")
    }

    func testReadingAsyncLetNeedsAwait() {
        assertError("""
        Task {
            async let a = 1
            log.log("\\(a)")
        }
        """, contains: "needs 'await'")
    }

    func testAsyncLetOutsideAnAsyncContext() {
        assertError("""
        func f() {
            async let a = 1
        }
        """, contains: "async let needs an async context")
    }

    func testUnknownName() {
        assertError("lgo.log(\"hi\")", contains: "cannot find 'lgo' in scope")
    }

    func testUnknownImplicitMember() {
        assertError("DispatchQueue.global(qos: .userInitated).async {}", contains: "unknown member '.userInitated'")
    }

    func testAssigningToALet() {
        assertError("""
        let x = 1
        x = 2
        """, contains: "'let' constant")
    }

    func testSyntaxErrorPointsAtTheLine() {
        let diags = Simulator.check("""
        log.log("ok")
        log.log("missing paren"
        """)
        XCTAssertEqual(diags.first?.line, 2)
        XCTAssertTrue(diags.first?.message.contains("')'") ?? false, diags.first?.message ?? "")
    }

    func testStructIsExplainedNotSilentlyMisparsed() {
        assertError("struct S {}", contains: "struct isn't supported")
    }

    func testCleanCodeHasNoDiagnostics() {
        XCTAssertEqual(Simulator.check("""
        let q = DispatchQueue(label: "x")
        q.async { log.log("hi") }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(10))
        }
        """), [])
    }
}
