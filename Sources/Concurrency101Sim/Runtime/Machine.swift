import Foundation

enum StepOutcome {
    case continued
    case blocked
    case suspended
    case hopped(Executor)
    case finished(ResumePayload)
}

/// Deterministic random numbers, so a seed replays the same interleaving.
struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}

/// The simulated runtime: a main thread, a GCD worker pool that grows when
/// workers block, a fixed cooperative pool for Swift tasks, actors, queues
/// and a virtual clock.
final class Machine {
    struct CoopJob {
        let fiber: Fiber
        let executor: Executor
        let priority: Int
        let seq: Int
    }

    enum MainJob {
        case work(DispatchWork)
        case resume(Fiber)
    }

    struct TimerEntry {
        let time: Double
        let seq: Int
        let action: () throws -> Void
    }

    let config: SimConfiguration
    let globals: GlobalTable
    var now: Double = 0
    let quantum = 0.000_01
    var steps = 0
    var rng: SplitMix64
    private var idCounter = 0
    private var seqCounter = 0
    var taskCounter = 0

    var threads: [SimThread] = []
    let mainThread: SimThread
    var gcdThreads: [SimThread] = []
    var coopThreads: [SimThread] = []

    var mainLane: [MainJob] = []
    var coopJobs: [CoopJob] = []
    var queues: [QueueObject] = []
    var globalQueues: [QoS: QueueObject] = [:]
    var mainQueue: QueueObject!
    var logObject: LogObject!

    var timers: [TimerEntry] = []
    var cancelledTimers: Set<Int> = []

    var fibers: [Fiber] = []
    var tasks: [TaskObject] = []
    var groups: [GroupObject] = []
    var semaphores: [SemaphoreObject] = []
    var continuations: [ContinuationObject] = []

    var events: [SimEvent] = []
    var eventsTruncated = false
    var warningsSeen: Set<String> = []
    var lostUpdates: [String: (count: Int, line: Int?)] = [:]
    var crash: (message: String, line: Int?, thread: String)?
    /// The fiber whose instruction is running, for natives such as
    /// `Thread.isMainThread` and `Task.isCancelled`.
    var currentFiber: Fiber?

    static let maxEvents = 4000

    init(config: SimConfiguration, globals: GlobalTable) {
        self.config = config
        self.globals = globals
        self.rng = SplitMix64(state: config.seed &* 0x2545_F491_4F6C_DD1D &+ 1)
        mainThread = SimThread(id: 0, name: "main", kind: .main)
        threads.append(mainThread)
        mainQueue = QueueObject(id: nextID(), kind: .main, label: "com.apple.main-thread", qos: .userInteractive)
        for qos in QoS.allCases {
            let q = QueueObject(id: nextID(), kind: .global, label: "com.apple.root.\(qos.rawValue)", qos: qos == .unspecified ? .default : qos)
            globalQueues[qos] = q
            queues.append(q)
        }
        logObject = LogObject(id: nextID())
    }

    func nextID() -> Int {
        idCounter += 1
        return idCounter
    }

    func nextSeq() -> Int {
        seqCounter += 1
        return seqCounter
    }

    // MARK: - Interpreter

    func step(_ f: Fiber) throws -> StepOutcome {
        currentFiber = f
        if let payload = f.resume {
            f.resume = nil
            switch payload {
            case .value(let v): return try deliverValue(f, v)
            case .error(let e): return try throwError(f, e)
            }
        }
        guard let frame = f.frames.last, let proto = frame.proto else {
            return .finished(.value(.void))
        }
        if frame.pc >= proto.code.count {
            return try doReturn(f, frame, .void)
        }
        let op = proto.code[frame.pc]
        frame.pc += 1
        steps += 1

        switch op {
        case .constant(let v):
            frame.stack.append(v)
        case .pop:
            _ = frame.stack.popLast()
        case .dup:
            frame.stack.append(frame.stack.last ?? .void)
        case .loadLocal(let s):
            guard let box = frame.slots[s] else { throw RuntimeFault(message: "internal: empty slot") }
            frame.stack.append(try read(box))
        case .loadUpvalue(let i):
            frame.stack.append(try read(frame.closure!.upvalues[i]))
        case .declareLocal(let s, let name):
            frame.slots[s] = Box(pop(frame).dereferenced, name: name)
        case .boxLocal(let s, let name):
            frame.slots[s] = Box(.uninitialized, name: name)
        case .setLocal(let s):
            let v = pop(frame).dereferenced
            if let box = frame.slots[s] {
                box.value = v
                box.version += 1
            } else {
                frame.slots[s] = Box(v, name: "local")
            }
        case .addressLocal(let s):
            if frame.slots[s] == nil { frame.slots[s] = Box(.uninitialized, name: "local") }
            frame.stack.append(.inoutRef(frame.slots[s]!))
        case .addressUpvalue(let i):
            frame.stack.append(.inoutRef(frame.closure!.upvalues[i]))
        case .addressMember(let name):
            let base = pop(frame).dereferenced
            frame.stack.append(.inoutRef(try fieldBox(base, name, f)))
        case .initField(let name):
            let v = pop(frame).dereferenced
            if case .object(let o)? = frame.slots[0]?.value, let inst = o as? InstanceObject {
                inst.fields[name]?.value = v
            }
        case .loadRef(let rmw):
            guard case .inoutRef(let box) = pop(frame) else { throw RuntimeFault(message: "internal: expected a reference") }
            if rmw { f.rmw.append((box, box.version)) }
            frame.stack.append(try read(box))
        case .storeRef(let rmw):
            let v = pop(frame).dereferenced
            guard case .inoutRef(let box) = pop(frame) else { throw RuntimeFault(message: "internal: expected a reference") }
            if rmw, let (recorded, version) = f.rmw.popLast(), recorded === box, box.version != version {
                recordLostUpdate(box.name, line: f.userLine)
            }
            box.value = v
            box.version += 1
        case .loadGlobal(let name):
            guard let entry = globals.entries[name] else { throw RuntimeFault(message: "cannot find '\(name)' in scope") }
            switch entry {
            case .value(let v): frame.stack.append(v)
            case .computed(let make): frame.stack.append(try make(self))
            }
        case .loadStatic(let type, let name):
            return try apply(try staticMember(type, name, MemberContext(machine: self, fiber: f, awaited: false)), f)
        case .getMember(let name, let awaited):
            let base = pop(frame)
            return try apply(try getMember(base, name, f, awaited: awaited), f)
        case .optionalGetMember(let name, let awaited):
            let base = pop(frame)
            if base.dereferenced.isNil {
                frame.stack.append(.nilValue)
            } else {
                return try apply(try getMember(base, name, f, awaited: awaited), f)
            }
        case .tupleIndex(let i):
            let v = pop(frame).dereferenced
            guard case .tuple(let items) = v, i < items.count else {
                throw RuntimeFault(message: "value of type \(v.typeName) has no element .\(i)")
            }
            frame.stack.append(items[i])
        case .subscriptGet:
            let index = pop(frame).dereferenced
            let base = pop(frame).dereferenced
            guard case .array(let items) = base, let i = index.asInt else {
                throw RuntimeFault(message: "can't subscript a value of type \(base.typeName)")
            }
            guard items.indices.contains(i) else { throw RuntimeFault(message: "Fatal error: Index out of range") }
            frame.stack.append(items[i])
        case .call(let argc, let labels, let trailingStart, let awaited):
            let values = Array(frame.stack.suffix(argc))
            frame.stack.removeLast(argc)
            let callee = pop(frame)
            let args = Arguments(values: values, labels: labels, trailingStart: trailingStart)
            return try invoke(f, callee, args, awaited: awaited)
        case .makeClosure(let child):
            var captured: [Box] = []
            captured.reserveCapacity(child.upvalues.count)
            for source in child.upvalues {
                switch source {
                case .local(let s):
                    if frame.slots[s] == nil { frame.slots[s] = Box(.uninitialized, name: "local") }
                    captured.append(frame.slots[s]!)
                case .upvalue(let i):
                    captured.append(frame.closure!.upvalues[i])
                }
            }
            let isolation: Isolation
            switch child.lexicalRule {
            case .main: isolation = .main
            case .nonisolated: isolation = .nonisolated
            case .enclosing, .actorSelf: isolation = frame.closure?.isolation ?? .nonisolated
            }
            frame.stack.append(.closure(Closure(proto: child, upvalues: captured, selfValue: nil, isolation: isolation)))
        case .makeTuple(let n):
            let items = Array(frame.stack.suffix(n)).map(\.dereferenced)
            frame.stack.removeLast(n)
            frame.stack.append(.tuple(items))
        case .makeArray(let n):
            let items = Array(frame.stack.suffix(n)).map(\.dereferenced)
            frame.stack.removeLast(n)
            frame.stack.append(.array(items))
        case .binary(let op):
            let b = pop(frame)
            let a = pop(frame)
            frame.stack.append(try binary(op, a, b))
        case .prefix(let op):
            let v = pop(frame).dereferenced
            switch (op, v) {
            case ("!", .bool(let b)): frame.stack.append(.bool(!b))
            case ("-", .int(let i)): frame.stack.append(.int(-i))
            case ("-", .double(let d)): frame.stack.append(.double(-d))
            default: throw RuntimeFault(message: "can't apply prefix \(op) to \(v.typeName)")
            }
        case .forceUnwrap:
            let v = pop(frame)
            if v.dereferenced.isNil {
                throw RuntimeFault(message: "Fatal error: Unexpectedly found nil while unwrapping an Optional value")
            }
            frame.stack.append(v)
        case .isType(let name):
            frame.stack.append(.bool(typeMatches(pop(frame).dereferenced, name)))
        case .castOptional(let name):
            let v = pop(frame).dereferenced
            frame.stack.append(typeMatches(v, name) ? v : .nilValue)
        case .interpolate(let n):
            let parts = frame.stack.suffix(n).map { $0.dereferenced.display }
            frame.stack.removeLast(n)
            frame.stack.append(.string(parts.joined()))
        case .implicitMember(let name):
            guard let entry = globals.implicitMembers[name] else { throw RuntimeFault(message: "unknown member '.\(name)'") }
            switch entry {
            case .value(let v): frame.stack.append(v)
            case .computed(let make): frame.stack.append(try make(self))
            }
        case .matchPattern:
            let pattern = pop(frame).dereferenced
            let subject = pop(frame).dereferenced
            if case .range(let lo, let hi) = pattern, let i = subject.asInt {
                frame.stack.append(.bool(i >= lo && i < hi))
            } else {
                frame.stack.append(.bool(Value.equal(subject, pattern)))
            }
        case .jump(let t):
            frame.pc = t
        case .jumpIfFalse(let t):
            if !(try truthy(pop(frame))) { frame.pc = t }
        case .jumpIfTrue(let t):
            if try truthy(pop(frame)) { frame.pc = t }
        case .jumpIfNil(let t):
            if (frame.stack.last ?? .nilValue).dereferenced.isNil {
                _ = frame.stack.popLast()
                frame.pc = t
            }
        case .jumpIfNotMissing(let slot, let t):
            if let box = frame.slots[slot], case .missingArgument = box.value {
                break
            }
            frame.pc = t
        case .ret:
            return try doReturn(f, frame, pop(frame))
        case .pushHandler(let t):
            frame.handlers.append((t, frame.stack.count))
        case .popHandler:
            _ = frame.handlers.popLast()
        case .throwTop:
            return try throwError(f, pop(frame).dereferenced)
        case .matchError(let name):
            frame.stack.append(.bool(errorMatches(frame.stack.last ?? .void, name)))
        case .registerDefer:
            guard case .closure(let c) = pop(frame) else { throw RuntimeFault(message: "internal: defer") }
            frame.defers.append(c)
        case .makeIterator:
            frame.stack.append(.object(try makeIterator(pop(frame).dereferenced)))
        case .asyncLetStart(let s, let name):
            let op = pop(frame)
            let task = try startTask(op, priority: nil, detached: false, childOf: f.task, group: nil, inheritIsolation: false, line: f.userLine)
            frame.slots[s] = Box(.object(AsyncLetHandle(id: nextID(), task: task, name: name)), name: name)
        case .awaitAsyncLet(let name):
            guard case .object(let o) = pop(frame), let handle = o as? AsyncLetHandle else {
                throw RuntimeFault(message: "internal: async let '\(name)'")
            }
            if let result = handle.task.result {
                return try apply(TaskObject.deliver(result, asResult: false), f)
            }
            handle.task.awaiters.append(f)
            return try apply(.suspend(.asyncLet(handle.task)), f)
        case .crash(let message):
            throw RuntimeFault(message: message)
        }
        return .continued
    }

    private func pop(_ frame: Frame) -> Value {
        frame.stack.popLast() ?? .void
    }

    private func read(_ box: Box) throws -> Value {
        switch box.value {
        case .uninitialized:
            throw RuntimeFault(message: "'\(box.name)' was used before it was given a value")
        default:
            return box.value
        }
    }

    private func truthy(_ v: Value) throws -> Bool {
        guard let b = v.dereferenced.asBool else {
            throw RuntimeFault(message: "expected a Bool condition, found \(v.dereferenced.typeName)")
        }
        return b
    }

    private func doReturn(_ f: Fiber, _ frame: Frame, _ value: Value) throws -> StepOutcome {
        var v = value.dereferenced
        if frame.proto?.isInit == true, let s = frame.slots.first??.value {
            v = s
        }
        if !frame.defers.isEmpty {
            frame.pending = .returning(v)
            return try runNextDefer(f, frame)
        }
        f.frames.removeLast()
        return try deliverValue(f, v)
    }

    private func runNextDefer(_ f: Fiber, _ frame: Frame) throws -> StepOutcome {
        let d = frame.defers.removeLast()
        return try callClosure(f, d, .empty, awaited: true)
    }

    /// Hands a callee's return value (or a wake value) to whoever is waiting.
    func deliverValue(_ f: Fiber, _ value: Value) throws -> StepOutcome {
        var v = value
        while true {
            guard let top = f.frames.last else {
                return .finished(.value(v))
            }
            if let then = top.nativeThen {
                f.frames.removeLast()
                let r = try then(v)
                if case .value(let x) = r {
                    v = x
                    continue
                }
                return try apply(r, f)
            }
            if let pending = top.pending {
                if !top.defers.isEmpty {
                    return try runNextDefer(f, top)
                }
                top.pending = nil
                f.frames.removeLast()
                switch pending {
                case .returning(let rv):
                    v = rv
                    continue
                case .throwing(let e):
                    return try throwError(f, e)
                }
            }
            top.stack.append(v)
            if top.executor != f.executor {
                return .hopped(top.executor)
            }
            return .continued
        }
    }

    func throwError(_ f: Fiber, _ error: Value) throws -> StepOutcome {
        f.rmw.removeAll()
        while true {
            guard let top = f.frames.last else {
                return .finished(.error(error))
            }
            if top.isNative {
                f.frames.removeLast()
                continue
            }
            if let h = top.handlers.popLast() {
                if top.stack.count > h.depth { top.stack.removeLast(top.stack.count - h.depth) }
                top.stack.append(error)
                top.pc = h.pc
                if top.executor != f.executor {
                    return .hopped(top.executor)
                }
                return .continued
            }
            if !top.defers.isEmpty {
                top.pending = .throwing(error)
                return try runNextDefer(f, top)
            }
            f.frames.removeLast()
        }
    }

    func apply(_ result: NativeResult, _ f: Fiber) throws -> StepOutcome {
        switch result {
        case .value(let v):
            return try deliverValue(f, v)
        case .throwError(let e):
            return try throwError(f, e)
        case .block(let reason, let then):
            if let then { f.frames.append(Frame(then: then, executor: f.executor)) }
            f.state = .blocked(reason)
            return .blocked
        case .suspend(let reason, let then):
            guard f.task != nil else {
                throw RuntimeFault(message: "\(reason.api) can only suspend inside a Task")
            }
            if let then { f.frames.append(Frame(then: then, executor: f.executor)) }
            f.state = .suspended(reason)
            return .suspended
        case .call(let callee, let args, let then):
            if let then { f.frames.append(Frame(then: then, executor: f.frames.last?.executor ?? f.executor)) }
            return try invoke(f, callee, args, awaited: true)
        }
    }

    // MARK: - Calls

    func invoke(_ f: Fiber, _ callee: Value, _ args: Arguments, awaited: Bool) throws -> StepOutcome {
        switch callee.dereferenced {
        case .closure(let c):
            return try callClosure(f, c, args, awaited: awaited)
        case .overloads(let cs):
            guard let c = cs.first(where: { bindArguments($0.proto, args) != nil }) else {
                throw RuntimeFault(message: "no version of '\(cs.first?.proto.name ?? "function")' takes (\(args.labelSignature))")
            }
            return try callClosure(f, c, args, awaited: awaited)
        case .native(let n):
            if n.isAsync && !awaited {
                throw RuntimeFault(message: "'\(n.name)' is async: call it with 'await'")
            }
            let ctx = NativeContext(machine: self, fiber: f, receiver: n.receiver, args: args, awaited: awaited, name: n.name)
            return try apply(try n.impl(ctx), f)
        case .type(let t):
            return try construct(f, t, args)
        default:
            throw RuntimeFault(message: "can't call a value of type \(callee.dereferenced.typeName)")
        }
    }

    func callClosure(_ f: Fiber, _ c: Closure, _ args: Arguments, awaited: Bool) throws -> StepOutcome {
        let proto = c.proto
        guard f.frames.count < 200 else {
            throw RuntimeFault(message: "stack overflow: too many nested calls (infinite recursion?)")
        }
        guard let bound = bindArguments(proto, args) else {
            let expected = proto.params.map { ($0.label ?? "_") + ":" }.joined()
            throw RuntimeFault(message: "'\(proto.name)' takes (\(expected)) but was called with (\(args.labelSignature))")
        }
        if proto.isAsync && !awaited {
            throw RuntimeFault(message: "'\(proto.name)' is async: call it with 'await'")
        }
        let target: Executor?
        switch proto.isolationRule {
        case .inherit: target = nil
        case .main: target = .main
        case .actorSelf, .closureLexical: target = c.isolation.executor
        case .pool: target = .pool
        }
        let callerExecutor = f.frames.last?.executor ?? f.executor
        let frame = Frame(closure: c, executor: target ?? callerExecutor)
        if proto.hasSelf {
            frame.slots[0] = Box(c.selfValue ?? .nilValue, name: "self")
        }
        for (i, slot) in proto.paramSlots.enumerated() {
            let name = i < proto.params.count ? proto.params[i].name : "arg"
            if i < bound.count, let v = bound[i] {
                if case .inoutRef(let box) = v {
                    frame.slots[slot] = box
                } else {
                    frame.slots[slot] = Box(v, name: name)
                }
            } else {
                frame.slots[slot] = Box(.missingArgument, name: name)
            }
        }
        if let target, target != f.executor {
            if !awaited {
                throw RuntimeFault(message: "'\(proto.name)' is isolated to \(describe(target)). Calling it from here needs 'await'.")
            }
            guard f.task != nil else {
                throw RuntimeFault(message: "'\(proto.name)' runs on \(describe(target)), and synchronous code can't hop there")
            }
            f.frames.append(frame)
            return .hopped(target)
        }
        f.frames.append(frame)
        return .continued
    }

    func describe(_ e: Executor) -> String {
        switch e {
        case .main: return "the main actor"
        case .pool: return "the cooperative pool"
        case .actor(let a): return a.display
        case .dispatch(let q): return q.display
        }
    }

    /// Matches call-site arguments to parameters. `nil` entries mean "use
    /// the default value".
    func bindArguments(_ proto: FunctionProto, _ args: Arguments) -> [Value?]? {
        let params = proto.params
        if proto.isClosure {
            if args.count < params.count { return nil }
            return Array(args.values.prefix(params.count))
        }
        var result: [Value?] = []
        var ai = 0
        for (pi, p) in params.enumerated() {
            guard ai < args.count else {
                if p.hasDefault {
                    result.append(nil)
                    continue
                }
                return nil
            }
            let label = args.labels[ai]
            let isTrailing = ai >= args.trailingStart
            if isTrailing && label == nil {
                // An unlabeled trailing closure skips defaulted parameters
                // while a later required one still needs it.
                if p.hasDefault && laterRequired(params, after: pi) >= args.count - ai {
                    result.append(nil)
                    continue
                }
                result.append(args.values[ai])
                ai += 1
                continue
            }
            if label == p.label {
                result.append(args.values[ai])
                ai += 1
                continue
            }
            if p.hasDefault {
                result.append(nil)
                continue
            }
            return nil
        }
        return ai == args.count ? result : nil
    }

    private func laterRequired(_ params: [ParamInfo], after index: Int) -> Int {
        params[(index + 1)...].filter { !$0.hasDefault }.count
    }

    private func construct(_ f: Fiber, _ t: TypeObject, _ args: Arguments) throws -> StepOutcome {
        switch t.kind {
        case .builtin:
            guard let ni = t.nativeInit else {
                throw RuntimeFault(message: "'\(t.name)' can't be created in the sandbox")
            }
            return try invoke(f, .native(ni), args, awaited: true)
        case .namespace:
            throw RuntimeFault(message: "'\(t.name)' is an enum namespace and has no initializer")
        case .classType, .actorType:
            let inst = InstanceObject(id: nextID(), type: t)
            let obj = Value.object(inst)
            var initClosure: Closure?
            if !t.inits.isEmpty {
                let candidates = t.inits.map {
                    Closure(proto: $0, upvalues: [], selfValue: obj, isolation: t.isActor ? .actor(inst) : (t.isMainActor ? .main : .nonisolated))
                }
                guard let match = candidates.first(where: { bindArguments($0.proto, args) != nil }) else {
                    throw RuntimeFault(message: "no init of \(t.name) takes (\(args.labelSignature))")
                }
                initClosure = match
            } else if args.count > 0 {
                throw RuntimeFault(message: "\(t.name) has no init that takes arguments")
            }
            let finish: (Value) throws -> NativeResult = { _ in
                inst.initializing = false
                return .value(obj)
            }
            let afterFields: (Value) throws -> NativeResult = { _ in
                if let ic = initClosure {
                    return .call(.closure(ic), args, then: finish)
                }
                return try finish(.void)
            }
            guard let fieldInit = t.fieldInit else {
                return try apply(try afterFields(.void), f)
            }
            let fc = Closure(proto: fieldInit, upvalues: [], selfValue: obj, isolation: .nonisolated)
            f.frames.append(Frame(then: afterFields, executor: f.frames.last?.executor ?? f.executor))
            return try callClosure(f, fc, .empty, awaited: true)
        }
    }

    // MARK: - Members

    func getMember(_ base: Value, _ name: String, _ f: Fiber, awaited: Bool) throws -> NativeResult {
        let ctx = MemberContext(machine: self, fiber: f, awaited: awaited)
        let v = base.dereferenced
        switch v {
        case .object(let o):
            if let inst = o as? InstanceObject {
                return try instanceMember(inst, name, ctx)
            }
            if let r = try o.member(name, ctx) { return r }
            throw RuntimeFault(message: "value of type '\(o.typeName)' has no member '\(name)'")
        case .type(let t):
            return try staticMember(t, name, ctx)
        case .string(let s):
            switch name {
            case "count": return .value(.int(s.count))
            case "isEmpty": return .value(.bool(s.isEmpty))
            case "description": return .value(.string(s))
            case "uppercased": return method("uppercased") { _ in .value(.string(s.uppercased())) }
            case "lowercased": return method("lowercased") { _ in .value(.string(s.lowercased())) }
            case "hasPrefix": return method("hasPrefix") { c in .value(.bool(s.hasPrefix(c.args.positional(0)?.asString ?? ""))) }
            case "hasSuffix": return method("hasSuffix") { c in .value(.bool(s.hasSuffix(c.args.positional(0)?.asString ?? ""))) }
            case "contains": return method("contains") { c in .value(.bool(s.contains(c.args.positional(0)?.asString ?? ""))) }
            default: break
            }
        case .array(let items):
            switch name {
            case "count": return .value(.int(items.count))
            case "isEmpty": return .value(.bool(items.isEmpty))
            case "first": return .value(items.first ?? .nilValue)
            case "last": return .value(items.last ?? .nilValue)
            case "description": return .value(.string(v.display))
            case "appending": return method("appending") { c in .value(.array(items + [c.args.positional(0) ?? .void])) }
            case "contains": return method("contains") { c in
                let needle = c.args.positional(0) ?? .void
                return .value(.bool(items.contains { Value.equal($0, needle) }))
            }
            default: break
            }
        case .range(let lo, let hi):
            switch name {
            case "count": return .value(.int(hi - lo))
            case "lowerBound": return .value(.int(lo))
            case "upperBound": return .value(.int(hi))
            case "contains": return method("contains") { c in
                let i = c.args.positional(0)?.asInt ?? Int.min
                return .value(.bool(i >= lo && i < hi))
            }
            default: break
            }
        case .date(let t):
            switch name {
            case "addingTimeInterval":
                return method("Date.addingTimeInterval") { c in
                    .value(.date(t + (c.args.positional(0)?.asDouble ?? 0)))
                }
            case "timeIntervalSince":
                return method("Date.timeIntervalSince") { c in
                    guard case .date(let other)? = c.args.positional(0) else {
                        throw RuntimeFault(message: "timeIntervalSince needs a Date")
                    }
                    return .value(.double(t - other))
                }
            case "timeIntervalSinceNow":
                return .value(.double(t - now))
            case "timeIntervalSince1970", "timeIntervalSinceReferenceDate":
                return .value(.double(t))
            default: break
            }
        case .dispatchTime(let t):
            if name == "uptimeNanoseconds" { return .value(.int(Int(t * 1_000_000_000))) }
        case .duration(let s):
            if name == "components" { return .value(.tuple([.int(Int(s)), .int(Int((s - Double(Int(s))) * 1e18))])) }
        case .error(_, let text):
            if name == "localizedDescription" || name == "description" { return .value(.string(text)) }
        case .enumCase(_, let c):
            if name == "rawValue" || name == "description" { return .value(.string(c)) }
        case .int(let i):
            if name == "description" { return .value(.string(String(i))) }
        case .double(let d):
            if name == "description" { return .value(.string(Value.formatDouble(d))) }
        case .nilValue:
            throw RuntimeFault(message: "Fatal error: the value is nil, so '.\(name)' can't be read (use ?. to read it safely)")
        default:
            break
        }
        throw RuntimeFault(message: "value of type '\(v.typeName)' has no member '\(name)'")
    }

    private func instanceMember(_ inst: InstanceObject, _ name: String, _ ctx: MemberContext) throws -> NativeResult {
        let t = inst.type
        if let box = inst.fields[name] {
            let isLet = t.fields.first { $0.name == name }?.isLet ?? false
            if t.isActor && !inst.initializing && !isLet && ctx.fiber.executor != .actor(inst) {
                if ctx.awaited, let getter = t.fieldGetters[name] {
                    let c = Closure(proto: getter, upvalues: [], selfValue: .object(inst), isolation: .actor(inst))
                    return .call(.closure(c), .empty, then: nil)
                }
                throw RuntimeFault(message: "actor-isolated property '\(name)' can't be read from outside \(inst.display) without 'await'")
            }
            if case .uninitialized = box.value {
                throw RuntimeFault(message: "property '\(name)' was read before it was given a value")
            }
            return .value(box.value)
        }
        if let getter = t.computed[name] {
            let c = Closure(proto: getter, upvalues: [], selfValue: .object(inst), isolation: isolationFor(getter, inst))
            return .call(.closure(c), .empty, then: nil)
        }
        if let protos = t.methods[name] {
            let closures = protos.map { Closure(proto: $0, upvalues: [], selfValue: .object(inst), isolation: isolationFor($0, inst)) }
            return .value(closures.count == 1 ? .closure(closures[0]) : .overloads(closures))
        }
        throw RuntimeFault(message: "value of type '\(t.name)' has no member '\(name)'")
    }

    private func isolationFor(_ proto: FunctionProto, _ inst: InstanceObject) -> Isolation {
        switch proto.isolationRule {
        case .actorSelf: return .actor(inst)
        case .main: return .main
        default: return .nonisolated
        }
    }

    /// The storage behind `object.name`, for assignment and `&object.name`.
    private func fieldBox(_ base: Value, _ name: String, _ f: Fiber) throws -> Box {
        guard case .object(let o) = base, let inst = o as? InstanceObject else {
            throw RuntimeFault(message: "can't assign to '\(name)' on a value of type \(base.typeName)")
        }
        guard let box = inst.fields[name] else {
            throw RuntimeFault(message: "value of type '\(inst.type.name)' has no stored property '\(name)'")
        }
        let isLet = inst.type.fields.first { $0.name == name }?.isLet ?? false
        if isLet && !inst.initializing {
            throw RuntimeFault(message: "cannot assign to property: '\(name)' is a 'let' constant")
        }
        if inst.type.isActor && !inst.initializing && f.executor != .actor(inst) {
            throw RuntimeFault(message: "actor-isolated property '\(name)' can only be changed from inside \(inst.display)")
        }
        return box
    }

    func staticMember(_ t: TypeObject, _ name: String, _ ctx: MemberContext) throws -> NativeResult {
        if name == "self" { return .value(.type(t)) }
        if let fns = t.staticFuncs[name] {
            return .value(fns.count == 1 ? .closure(fns[0]) : .overloads(fns))
        }
        if let nested = t.nestedTypes[name] { return .value(.type(nested)) }
        if t.cases.contains(name) { return .value(.enumCase(t.name, name)) }
        if let stored = t.staticStored[name] {
            if let box = t.staticStorage[name] { return .value(box.value) }
            let c = Closure(proto: stored.proto, upvalues: [], selfValue: nil, isolation: .nonisolated)
            return .call(.closure(c), .empty, then: { v in
                if let box = t.staticStorage[name] { return .value(box.value) }
                t.staticStorage[name] = Box(v, name: name)
                return .value(v)
            })
        }
        if let getter = t.staticComputed[name] {
            let c = Closure(proto: getter, upvalues: [], selfValue: nil, isolation: getter.isolationRule == .main ? .main : .nonisolated)
            return .call(.closure(c), .empty, then: nil)
        }
        if let native = t.nativeStatics[name] {
            switch native {
            case .function(let fn): return .value(.native(fn))
            case .property(let p): return .value(try p(self))
            }
        }
        throw RuntimeFault(message: "type '\(t.name)' has no member '\(name)'")
    }

    // MARK: - Operators and types

    func binary(_ op: String, _ lhs: Value, _ rhs: Value) throws -> Value {
        let a = lhs.dereferenced
        let b = rhs.dereferenced
        switch op {
        case "==": return .bool(Value.equal(a, b))
        case "!=": return .bool(!Value.equal(a, b))
        case "..<", "...":
            guard let lo = a.asInt, let hi = b.asInt else {
                throw RuntimeFault(message: "ranges in the sandbox need Int bounds")
            }
            let upper = op == "..." ? hi + 1 : hi
            guard lo <= upper else { throw RuntimeFault(message: "Fatal error: Range requires lowerBound <= upperBound") }
            return .range(lo, upper)
        default:
            break
        }
        switch (op, a, b) {
        case ("+", .string(let x), .string(let y)): return .string(x + y)
        case ("+", .array(let x), .array(let y)): return .array(x + y)
        case ("+", .dispatchTime(let t), _) where b.asDouble != nil: return .dispatchTime(t + b.asDouble!)
        case ("+", _, .dispatchTime(let t)) where a.asDouble != nil: return .dispatchTime(t + a.asDouble!)
        case ("-", .dispatchTime(let t), _) where b.asDouble != nil: return .dispatchTime(t - b.asDouble!)
        case ("+", .date(let t), _) where b.asDouble != nil: return .date(t + b.asDouble!)
        case ("-", .date(let t), _) where b.asDouble != nil: return .date(t - b.asDouble!)
        case ("-", .date(let x), .date(let y)): return .double(x - y)
        case ("+", .duration(let x), .duration(let y)): return .duration(x + y)
        case ("*", .duration(let x), _) where b.asDouble != nil: return .duration(x * b.asDouble!)
        default: break
        }
        if ["<", ">", "<=", ">="].contains(op) {
            let ordered: (Double, Double)?
            switch (a, b) {
            case (.dispatchTime(let x), .dispatchTime(let y)), (.date(let x), .date(let y)), (.duration(let x), .duration(let y)):
                ordered = (x, y)
            case (.string(let x), .string(let y)):
                switch op {
                case "<": return .bool(x < y)
                case ">": return .bool(x > y)
                case "<=": return .bool(x <= y)
                default: return .bool(x >= y)
                }
            default:
                if let x = a.asDouble, let y = b.asDouble { ordered = (x, y) } else { ordered = nil }
            }
            guard let (x, y) = ordered else {
                throw RuntimeFault(message: "can't compare \(a.typeName) and \(b.typeName) with \(op)")
            }
            switch op {
            case "<": return .bool(x < y)
            case ">": return .bool(x > y)
            case "<=": return .bool(x <= y)
            default: return .bool(x >= y)
            }
        }
        if case .int(let x) = a, case .int(let y) = b {
            switch op {
            case "+":
                let r = x.addingReportingOverflow(y)
                if r.overflow { throw RuntimeFault(message: "Fatal error: arithmetic overflow") }
                return .int(r.partialValue)
            case "-":
                let r = x.subtractingReportingOverflow(y)
                if r.overflow { throw RuntimeFault(message: "Fatal error: arithmetic overflow") }
                return .int(r.partialValue)
            case "*":
                let r = x.multipliedReportingOverflow(by: y)
                if r.overflow { throw RuntimeFault(message: "Fatal error: arithmetic overflow") }
                return .int(r.partialValue)
            case "/":
                if y == 0 { throw RuntimeFault(message: "Fatal error: Division by zero") }
                return .int(x / y)
            case "%":
                if y == 0 { throw RuntimeFault(message: "Fatal error: Division by zero in remainder operation") }
                return .int(x % y)
            default: break
            }
        }
        if let x = a.asDouble, let y = b.asDouble {
            switch op {
            case "+": return .double(x + y)
            case "-": return .double(x - y)
            case "*": return .double(x * y)
            case "/": return .double(x / y)
            case "%": return .double(x.truncatingRemainder(dividingBy: y))
            default: break
            }
        }
        throw RuntimeFault(message: "can't apply \(op) to \(a.typeName) and \(b.typeName)")
    }

    func typeMatches(_ v: Value, _ rawName: String) -> Bool {
        var name = rawName
        while name.hasSuffix("?") || name.hasSuffix("!") { name.removeLast() }
        if name == "Any" || name == "AnyObject" { return true }
        switch v {
        case .int: return name == "Int"
        case .double: return name == "Double" || name == "TimeInterval"
        case .string: return name == "String"
        case .bool: return name == "Bool"
        case .error(let t, _): return name == t || name == "Error"
        case .enumCase(let t, _): return name == t || name == "Error"
        case .object(let o):
            if let inst = o as? InstanceObject { return inst.type.name == name || inst.type.fullName == name }
            return o.typeName == name
        case .nilValue: return false
        default: return v.typeName == name
        }
    }

    private func errorMatches(_ v: Value, _ name: String) -> Bool {
        switch v.dereferenced {
        case .error(let t, _): return t == name || name == "Error"
        case .enumCase(let t, _): return t == name || name == "Error"
        case .object(let o): return o.typeName == name || name == "Error"
        default: return name == "Error" || name == "Any"
        }
    }

    private func makeIterator(_ v: Value) throws -> SimObject {
        switch v {
        case .range(let lo, let hi): return IteratorObject(id: nextID(), source: .range(lo, hi))
        case .array(let items): return IteratorObject(id: nextID(), source: .array(items))
        case .object(let o):
            if let g = o as? TaskGroupObject { return IteratorObject(id: nextID(), source: .group(g)) }
            if let it = o as? IteratorObject { return it }
        default: break
        }
        throw RuntimeFault(message: "can't loop over a value of type \(v.typeName)")
    }
}
