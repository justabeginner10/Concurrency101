/// A variable's storage. Closures capture boxes, so a `var` captured by a
/// GCD block is shared the way it is in Swift. `version` moves on every
/// write, which is how a lost `+=` update is spotted.
final class Box {
    var value: Value
    var version = 0
    let name: String

    init(_ value: Value, name: String) {
        self.value = value
        self.name = name
    }
}

/// Runtime values. The sandbox is dynamically typed: Swift's types are
/// parsed for readability and then ignored.
enum Value {
    case void
    case nilValue
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case tuple([Value])
    case array([Value])
    case range(Int, Int)
    case closure(Closure)
    case overloads([Closure])
    case native(NativeFunction)
    case object(SimObject)
    case type(TypeObject)
    case enumCase(String, String)
    case dispatchTime(Double)
    case date(Double)
    case duration(Double)
    case error(String, String)
    case inoutRef(Box)
    case uninitialized
    case missingArgument

    var isNil: Bool {
        if case .nilValue = self { return true }
        return false
    }

    var typeName: String {
        switch self {
        case .void: return "Void"
        case .nilValue: return "nil"
        case .bool: return "Bool"
        case .int: return "Int"
        case .double: return "Double"
        case .string: return "String"
        case .tuple: return "tuple"
        case .array: return "Array"
        case .range: return "Range"
        case .closure, .overloads, .native: return "function"
        case .object(let o): return o.typeName
        case .type(let t): return "\(t.name).Type"
        case .enumCase(let t, _): return t
        case .dispatchTime: return "DispatchTime"
        case .date: return "Date"
        case .duration: return "Duration"
        case .error(let t, _): return t
        case .inoutRef: return "inout"
        case .uninitialized, .missingArgument: return "uninitialized"
        }
    }

    /// What `"\(value)"` and `print(value)` show.
    var display: String {
        switch self {
        case .void: return "()"
        case .nilValue: return "nil"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return Self.formatDouble(d)
        case .string(let s): return s
        case .tuple(let items): return "(" + items.map(\.debugDisplay).joined(separator: ", ") + ")"
        case .array(let items): return "[" + items.map(\.debugDisplay).joined(separator: ", ") + "]"
        case .range(let lo, let hi): return "\(lo)..<\(hi)"
        case .closure, .overloads, .native: return "(Function)"
        case .object(let o): return o.display
        case .type(let t): return t.name
        case .enumCase(_, let c): return c
        case .dispatchTime(let t): return t.isInfinite ? "DispatchTime.distantFuture" : "DispatchTime(\(Self.formatDouble(t))s)"
        case .date(let t): return "Date(+\(Self.formatDouble(t))s)"
        case .duration(let s): return "\(Self.formatDouble(s)) seconds"
        case .error(_, let text): return text
        case .inoutRef(let box): return box.value.display
        case .uninitialized, .missingArgument: return "<uninitialized>"
        }
    }

    var debugDisplay: String {
        if case .string(let s) = self { return "\"\(s)\"" }
        return display
    }

    static func formatDouble(_ d: Double) -> String {
        if d.isInfinite { return d > 0 ? "inf" : "-inf" }
        return String(d)
    }

    var asDouble: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }

    var asInt: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    var asBool: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var asString: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var asObject: SimObject? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Strips an `&x` reference down to the value it points at.
    var dereferenced: Value {
        if case .inoutRef(let box) = self { return box.value }
        return self
    }

    var isCallable: Bool {
        switch self {
        case .closure, .overloads, .native, .type: return true
        default: return false
        }
    }

    static func equal(_ lhs: Value, _ rhs: Value) -> Bool {
        let a = lhs.dereferenced
        let b = rhs.dereferenced
        if let x = a.asDouble, let y = b.asDouble { return x == y }
        switch a {
        case .void:
            if case .void = b { return true }
        case .nilValue:
            return b.isNil
        case .bool(let x):
            if case .bool(let y) = b { return x == y }
        case .string(let x):
            if case .string(let y) = b { return x == y }
        case .enumCase(_, let x):
            if case .enumCase(_, let y) = b { return x == y }
        case .tuple(let x), .array(let x):
            switch b {
            case .tuple(let y), .array(let y):
                return x.count == y.count && zip(x, y).allSatisfy { equal($0, $1) }
            default:
                return false
            }
        case .range(let lo, let hi):
            if case .range(let lo2, let hi2) = b { return lo == lo2 && hi == hi2 }
        case .object(let x):
            if case .object(let y) = b { return x === y }
        case .type(let x):
            if case .type(let y) = b { return x === y }
        case .dispatchTime(let x):
            if case .dispatchTime(let y) = b { return x == y }
        case .date(let x):
            if case .date(let y) = b { return x == y }
        case .duration(let x):
            if case .duration(let y) = b { return x == y }
        case .error(let t, let d):
            if case .error(let t2, let d2) = b { return t == t2 && d == d2 }
        default:
            break
        }
        return false
    }
}

/// A user function or closure plus the boxes it captured.
final class Closure {
    let proto: FunctionProto
    let upvalues: [Box]
    let selfValue: Value?
    /// Where a `Task { }` created inside this closure would run.
    let isolation: Isolation

    init(proto: FunctionProto, upvalues: [Box], selfValue: Value?, isolation: Isolation) {
        self.proto = proto
        self.upvalues = upvalues
        self.selfValue = selfValue
        self.isolation = isolation
    }

    func bound(to receiver: Value) -> Closure {
        var iso = isolation
        if proto.isolationRule == .actorSelf, case .object(let o) = receiver, let inst = o as? InstanceObject {
            iso = .actor(inst)
        }
        return Closure(proto: proto, upvalues: upvalues, selfValue: receiver, isolation: iso)
    }
}

/// Static isolation, used for `Task { }` inheritance and async closure hops.
enum Isolation {
    case main
    case actor(InstanceObject)
    case nonisolated

    var executor: Executor? {
        switch self {
        case .main: return .main
        case .actor(let a): return .actor(a)
        case .nonisolated: return nil
        }
    }
}

/// Where a piece of work is allowed to run.
enum Executor: Equatable {
    case main
    case pool
    case actor(InstanceObject)
    case dispatch(QueueObject)

    static func == (lhs: Executor, rhs: Executor) -> Bool {
        switch (lhs, rhs) {
        case (.main, .main), (.pool, .pool): return true
        case (.actor(let a), .actor(let b)): return a === b
        case (.dispatch(let a), .dispatch(let b)): return a === b
        default: return false
        }
    }
}

/// Arguments as written at the call site.
struct Arguments {
    var values: [Value]
    var labels: [String?]
    /// Index of the first trailing closure, or `values.count`.
    var trailingStart: Int

    static let empty = Arguments(values: [], labels: [], trailingStart: 0)

    var count: Int { values.count }

    func value(_ label: String?) -> Value? {
        guard let i = labels.firstIndex(where: { $0 == label }) else { return nil }
        return values[i].dereferenced
    }

    func positional(_ index: Int) -> Value? {
        var n = 0
        for (i, l) in labels.enumerated() where l == nil {
            if n == index { return values[i].dereferenced }
            n += 1
        }
        return nil
    }

    /// The closure argument: labeled, or the trailing closure.
    func closure(_ label: String) -> Value? {
        if let v = value(label) { return v }
        if trailingStart < values.count, labels[trailingStart] == nil { return values[trailingStart] }
        return nil
    }

    var labelSignature: String {
        labels.map { ($0 ?? "_") + ":" }.joined()
    }
}

/// A built-in implemented in Swift.
final class NativeFunction {
    let name: String
    let isAsync: Bool
    let throwsFlag: Bool
    let receiver: Value?
    let impl: (NativeContext) throws -> NativeResult

    init(_ name: String, isAsync: Bool = false, throwsFlag: Bool = false, receiver: Value? = nil, impl: @escaping (NativeContext) throws -> NativeResult) {
        self.name = name
        self.isAsync = isAsync
        self.throwsFlag = throwsFlag
        self.receiver = receiver
        self.impl = impl
    }

    func bound(to receiver: Value) -> NativeFunction {
        NativeFunction(name, isAsync: isAsync, throwsFlag: throwsFlag, receiver: receiver, impl: impl)
    }
}

struct NativeContext {
    unowned let machine: Machine
    let fiber: Fiber
    let receiver: Value?
    let args: Arguments
    let awaited: Bool
    let name: String
}

/// What a built-in asks the machine to do.
enum NativeResult {
    case value(Value)
    case throwError(Value)
    /// The fiber keeps its thread and waits (sync, semaphore.wait, Thread.sleep).
    /// `then` receives the value it is woken with.
    case block(BlockReason, then: ((Value) throws -> NativeResult)? = nil)
    /// The fiber gives its thread back and waits (await Task.sleep, await a task).
    case suspend(SuspendReason, then: ((Value) throws -> NativeResult)? = nil)
    /// Call `callee` in place; `then` receives its result.
    case call(Value, Arguments, then: ((Value) throws -> NativeResult)?)
}

/// A crash: the real app would trap here.
struct RuntimeFault: Error {
    var message: String
}
