import XCTest
@testable import Concurrency101Sim

final class BasicsTests: XCTestCase {
    func testPreludeCompilesCleanly() {
        XCTAssertEqual(Simulator.check(""), [])
    }

    func testLogPrintsInOrderOnMain() {
        let run = simulate("""
        log.log("one")
        print("two", 2)
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["one", "two 2"])
        XCTAssertTrue(run.events.allSatisfy(\.isMainThread))
    }

    func testVariablesLoopsAndInterpolation() {
        let run = simulate("""
        var total = 0
        for i in 0..<5 where i != 2 {
            total += i
        }
        let pair = (total, "done")
        log.log("total \\(pair.0) \\(pair.1)")
        if total > 3, let x = Optional(total) {
            log.log("x \\(x)")
        } else {
            log.log("no")
        }
        """.replacingOccurrences(of: "Optional(total)", with: "total"))
        assertFinished(run)
        XCTAssertEqual(lines(run), ["total 8 done", "x 8"])
    }

    func testFunctionsLabelsDefaultsAndClosures() {
        let run = simulate("""
        func greet(_ name: String, punctuation: String = "!") -> String {
            "hi \\(name)\\(punctuation)"
        }
        let twice = { (x: Int) -> Int in x * 2 }
        log.log(greet("ada"))
        log.log(greet("bob", punctuation: "?"))
        log.log("\\(twice(21))")
        log.log("\\([1, 2, 3].count)")
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["hi ada!", "hi bob?", "42", "3"])
    }

    func testClosuresCaptureVariablesByReference() {
        let run = simulate("""
        var count = 0
        let bump = { count += 1 }
        bump()
        bump()
        log.log("\\(count)")
        """)
        XCTAssertEqual(lines(run), ["2"])
    }

    func testEachLoopIterationGetsItsOwnVariable() {
        let run = simulate("""
        var blocks: [() -> Void] = []
        for i in 0..<3 {
            blocks = blocks.appending({ log.log("\\(i)") })
        }
        for b in blocks { b() }
        """)
        XCTAssertEqual(lines(run), ["0", "1", "2"])
    }

    func testClassesAndSwitch() {
        let run = simulate("""
        enum Mood { case calm, busy }
        final class Box {
            var value = 1
            let name: String
            init(name: String) { self.name = name }
            func bump() { value += 1 }
            var doubled: Int { value * 2 }
        }
        let b = Box(name: "b")
        b.bump()
        log.log("\\(b.name) \\(b.value) \\(b.doubled)")
        let mood = Mood.busy
        switch mood {
        case .calm: log.log("calm")
        case .busy: log.log("busy")
        }
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["b 2 4", "busy"])
    }

    func testErrorsDoCatchAndDefer() {
        let run = simulate("""
        enum LoadError: Error { case timeout }
        func load(fail: Bool) throws -> String {
            defer { log.log("cleanup") }
            if fail { throw LoadError.timeout }
            return "ok"
        }
        do {
            log.log(try load(fail: false))
            _ = try load(fail: true)
        } catch is LoadError {
            log.log("caught timeout")
        }
        let maybe = try? load(fail: true)
        log.log("maybe \\(maybe == nil)")
        """)
        assertFinished(run)
        XCTAssertEqual(lines(run), ["cleanup", "ok", "cleanup", "caught timeout", "cleanup", "maybe true"])
    }

    func testCurlyQuotesFromAnIPhoneKeyboardStillParse() {
        let run = simulate("log.log(\u{201C}smart\u{201D})")
        XCTAssertEqual(lines(run), ["smart"])
    }
}
