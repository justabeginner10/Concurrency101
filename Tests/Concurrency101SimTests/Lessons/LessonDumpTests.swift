import XCTest
@testable import Concurrency101Sim

/// Prints every lesson's simulated trace. Not an assertion test: run it
/// with `SIM_DUMP=1 swift test --filter LessonDumpTests` when changing the
/// engine, to eyeball what learners will see.
final class LessonDumpTests: XCTestCase {
    func testDumpEveryLesson() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIM_DUMP"] == "1")
        for lesson in LessonSnippets.all {
            for (variant, source) in [("101", lesson.teaching), ("apple", lesson.apple)] {
                let run = Simulator.run(source)
                print("===== \(lesson.id) [\(variant)] outcome: \(run.outcome) end=\(String(format: "%.3f", run.endTime)) steps=\(run.steps)")
                for d in run.diagnostics { print("  diag \(d.line):\(d.column) \(d.message)") }
                for e in run.events {
                    print(String(format: "  %8.3f  %-5@ %-28@ %@", e.time, e.thread as NSString, e.context as NSString, e.text as NSString))
                }
                for n in run.notes { print("  note[\(n.kind)] \(n.text)") }
            }
        }
    }
}
