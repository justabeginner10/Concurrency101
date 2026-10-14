import XCTest
@testable import Concurrency101Sim

/// Runs `source` and fails the test on compile errors, so each test can
/// focus on behavior.
func simulate(
    _ source: String,
    cores: Int = 4,
    seed: UInt64 = 1,
    file: StaticString = #filePath,
    line: UInt = #line
) -> SimRun {
    let run = Simulator.run(source, configuration: SimConfiguration(cores: cores, seed: seed))
    let errors = run.diagnostics.filter { $0.severity == .error }
    if !errors.isEmpty {
        let text = errors.map { "\($0.line):\($0.column) \($0.message)" }.joined(separator: "\n")
        XCTFail("compile errors:\n\(text)", file: file, line: line)
    }
    return run
}

func lines(_ run: SimRun) -> [String] {
    run.logLines
}

/// Index of the first log line containing `text`, or nil.
func position(_ text: String, in run: SimRun) -> Int? {
    run.logLines.firstIndex { $0.contains(text) }
}

func event(_ text: String, in run: SimRun) -> SimEvent? {
    run.events.first { $0.text.contains(text) }
}

func assertFinished(_ run: SimRun, file: StaticString = #filePath, line: UInt = #line) {
    guard case .finished = run.outcome else {
        XCTFail("expected the run to finish, got \(run.outcome)\nlog:\n\(run.logLines.joined(separator: "\n"))", file: file, line: line)
        return
    }
}

func assertOrder(_ first: String, before second: String, in run: SimRun, file: StaticString = #filePath, line: UInt = #line) {
    guard let a = position(first, in: run) else {
        XCTFail("missing line containing '\(first)'\nlog:\n\(run.logLines.joined(separator: "\n"))", file: file, line: line)
        return
    }
    guard let b = position(second, in: run) else {
        XCTFail("missing line containing '\(second)'\nlog:\n\(run.logLines.joined(separator: "\n"))", file: file, line: line)
        return
    }
    XCTAssertLessThan(a, b, "'\(first)' should print before '\(second)'\nlog:\n\(run.logLines.joined(separator: "\n"))", file: file, line: line)
}

func stall(_ run: SimRun, file: StaticString = #filePath, line: UInt = #line) -> SimStall? {
    if case .deadlock(let s) = run.outcome { return s }
    XCTFail("expected a deadlock, got \(run.outcome)", file: file, line: line)
    return nil
}

func compileErrors(_ source: String) -> [String] {
    Simulator.check(source).filter { $0.severity == .error }.map(\.message)
}
