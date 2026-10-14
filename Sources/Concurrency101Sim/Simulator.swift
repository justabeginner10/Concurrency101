/// Runs a learner's Swift snippet on a simulated runtime instead of the
/// real one: a main thread, a GCD worker pool, a cooperative pool for Swift
/// tasks, actors, queues and a virtual clock. Nothing real is scheduled, so
/// a deadlock is reported instead of freezing the app.
///
/// This is a model, not the real runtime. It aims to show the same
/// orderings and failure modes the real runtime can show for the APIs the
/// lessons use; it does not reproduce exact timings, thread counts, or every
/// API.
public enum Simulator {
    /// Parses and compiles without running. Use for inline errors while
    /// the learner types.
    public static func check(_ source: String) -> [SimDiagnostic] {
        compile(source).diagnostics
    }

    public static func run(_ source: String, configuration: SimConfiguration = SimConfiguration()) -> SimRun {
        let compiled = compile(source)
        guard let entry = compiled.entry, !compiled.diagnostics.contains(where: { $0.severity == .error }) else {
            return SimRun(diagnostics: compiled.diagnostics, events: [], lanes: [], outcome: .compileFailed, notes: [], endTime: 0, steps: 0)
        }
        let machine = Machine(config: configuration, globals: compiled.globals)
        let stop = machine.run(entry: entry)
        machine.closeAllSegments()

        let outcome: SimOutcome
        switch stop {
        case .crashed:
            let c = machine.crash ?? ("crashed", nil, "?")
            outcome = .crashed(message: c.message, line: c.line, thread: c.thread)
        case .stepLimit:
            outcome = .stepLimit
        case .timeLimit:
            outcome = machine.hasStuckWork && machine.timers.isEmpty ? .deadlock(machine.stallReport()) : .timeLimit
        case .idle:
            outcome = machine.hasStuckWork ? .deadlock(machine.stallReport()) : .finished
        }
        return SimRun(
            diagnostics: compiled.diagnostics,
            events: machine.events,
            lanes: machine.lanes(),
            outcome: outcome,
            notes: machine.notes(stalled: { if case .deadlock = outcome { return true }; return false }()),
            endTime: machine.now,
            steps: machine.steps
        )
    }

    private struct Compiled {
        var globals: GlobalTable
        var entry: FunctionProto?
        var diagnostics: [SimDiagnostic]
    }

    private static func compile(_ source: String) -> Compiled {
        let globals = Builtins.makeGlobals()
        var diagnostics: [SimDiagnostic] = []
        do {
            let prelude = try Parser.parse(Prelude.source)
            let compiler = Compiler(globals: globals, isPrelude: true)
            _ = compiler.compileProgram(prelude)
            for d in compiler.diagnostics {
                diagnostics.append(SimDiagnostic(line: 0, column: 0, message: "internal prelude error at \(d.line):\(d.column): \(d.message)"))
            }
        } catch let e as SyntaxError {
            diagnostics.append(SimDiagnostic(line: 0, column: 0, message: "internal prelude error at \(e.loc.line):\(e.loc.column): \(e.message)"))
            return Compiled(globals: globals, entry: nil, diagnostics: diagnostics)
        } catch {
            return Compiled(globals: globals, entry: nil, diagnostics: [SimDiagnostic(line: 0, column: 0, message: "\(error)")])
        }

        let stmts: [Stmt]
        do {
            stmts = try Parser.parse(source)
        } catch let e as SyntaxError {
            diagnostics.append(SimDiagnostic(line: e.loc.line, column: e.loc.column, message: e.message))
            return Compiled(globals: globals, entry: nil, diagnostics: diagnostics)
        } catch {
            diagnostics.append(SimDiagnostic(line: 1, column: 1, message: "\(error)"))
            return Compiled(globals: globals, entry: nil, diagnostics: diagnostics)
        }
        let compiler = Compiler(globals: globals, isPrelude: false)
        let entry = compiler.compileProgram(stmts)
        diagnostics += compiler.diagnostics.sorted { ($0.line, $0.column) < ($1.line, $1.column) }
        return Compiled(globals: globals, entry: entry, diagnostics: diagnostics)
    }
}

public struct SimConfiguration: Sendable, Hashable {
    /// CPU cores: the cooperative pool has exactly this many threads, and
    /// GCD keeps this many running before it adds threads for blocked ones.
    public var cores: Int
    /// Same seed, same interleaving. Change it to see another valid order.
    public var seed: UInt64
    public var maxSteps: Int
    /// Virtual seconds.
    public var maxTime: Double

    public init(cores: Int = 4, seed: UInt64 = 1, maxSteps: Int = 3_000_000, maxTime: Double = 120) {
        self.cores = max(1, min(cores, 16))
        self.seed = seed
        self.maxSteps = maxSteps
        self.maxTime = maxTime
    }
}

/// A line the program logged (or a runtime warning), stamped with the
/// virtual time and the thread it ran on.
public struct SimEvent: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable {
        case log
        case warning
    }

    public let id: Int
    public let time: Double
    public let thread: String
    public let threadID: Int
    public let isMainThread: Bool
    /// The queue, actor, or task the line ran in.
    public let context: String
    public let text: String
    public let line: Int?
    public let kind: Kind
}

/// What one thread was doing over time.
public struct SimLane: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable {
        case main
        case gcd
        case cooperative
    }

    public let id: Int
    public let name: String
    public let kind: Kind
    public let segments: [SimSegment]
}

public struct SimSegment: Sendable, Hashable {
    public let start: Double
    public let end: Double
    public let label: String
    /// The thread was held but not running (sync, sleep, semaphore).
    public let isBlocked: Bool
    public let line: Int?
    /// Still open when the run ended (blocked forever, or cut off).
    public let unfinished: Bool
}

public struct SimStall: Sendable, Hashable {
    public let headline: String
    public let details: [String]
    public let lines: [Int]
    /// The main thread is blocked: in a real app the UI would be frozen.
    public let mainThreadFrozen: Bool
}

public enum SimOutcome: Sendable, Hashable {
    case finished
    case deadlock(SimStall)
    case crashed(message: String, line: Int?, thread: String)
    case stepLimit
    case timeLimit
    case compileFailed
}

public struct SimNote: Sendable, Hashable {
    public enum Kind: String, Sendable {
        case info
        case warning
    }

    public let kind: Kind
    public let text: String
    public let line: Int?
}

public struct SimRun: Sendable {
    public let diagnostics: [SimDiagnostic]
    public let events: [SimEvent]
    public let lanes: [SimLane]
    public let outcome: SimOutcome
    public let notes: [SimNote]
    /// Virtual seconds when the run stopped.
    public let endTime: Double
    public let steps: Int

    public var logLines: [String] {
        events.filter { $0.kind == .log }.map(\.text)
    }
}
