/// Built-in globals: the parts of Foundation, Dispatch and the Swift
/// concurrency runtime the sandbox models.
enum Builtins {
    static func makeGlobals() -> GlobalTable {
        let g = GlobalTable()

        func type(_ name: String) -> TypeObject {
            let t = TypeObject(name: name, kind: .builtin)
            g.entries[name] = .value(.type(t))
            return t
        }
        func fn(_ name: String, isAsync: Bool = false, throwsFlag: Bool = false, _ impl: @escaping (NativeContext) throws -> NativeResult) -> NativeFunction {
            NativeFunction(name, isAsync: isAsync, throwsFlag: throwsFlag, impl: impl)
        }

        // MARK: Plain types used as values (`Void.self`, `of: Int.self`)
        for name in ["Void", "Never", "Int", "Double", "String", "Bool", "Any", "Error", "Sendable", "TimeInterval", "UInt64", "Float"] {
            let t = type(name)
            switch name {
            case "Int":
                t.nativeInit = fn("Int") { c in
                    let v = c.args.positional(0) ?? .int(0)
                    switch v {
                    case .int: return .value(v)
                    case .double(let d): return .value(.int(Int(d)))
                    case .string(let s): return .value(Int(s).map(Value.int) ?? .nilValue)
                    default: throw RuntimeFault(message: "Int(_:) can't convert \(v.typeName)")
                    }
                }
                t.nativeStatics["random"] = .function(fn("Int.random") { c in
                    guard case .range(let lo, let hi)? = c.args.value("in"), hi > lo else {
                        throw RuntimeFault(message: "Int.random(in:) needs a non-empty range like 0..<10")
                    }
                    return .value(.int(c.machine.rng.int(lo...(hi - 1))))
                })
                t.nativeStatics["max"] = .property { _ in .int(Int.max) }
                t.nativeStatics["min"] = .property { _ in .int(Int.min) }
            case "Double", "TimeInterval", "Float":
                t.nativeInit = fn(name) { c in
                    let v = c.args.positional(0) ?? .double(0)
                    if let d = v.asDouble { return .value(.double(d)) }
                    if let s = v.asString { return .value(Double(s).map(Value.double) ?? .nilValue) }
                    throw RuntimeFault(message: "\(name)(_:) can't convert \(v.typeName)")
                }
            case "UInt64":
                t.nativeInit = fn(name) { c in .value(.int(Int(c.args.positional(0)?.asDouble ?? 0))) }
            case "String":
                t.nativeInit = fn("String") { c in
                    if let v = c.args.value("describing") { return .value(.string(v.display)) }
                    if let v = c.args.positional(0) { return .value(.string(v.display)) }
                    return .value(.string(""))
                }
            case "Bool":
                t.nativeInit = fn("Bool") { c in .value(c.args.positional(0) ?? .bool(false)) }
            default:
                break
            }
        }

        // MARK: Output
        g.entries["log"] = .computed { m in .object(m.logObject) }
        g.entries["print"] = .value(.native(fn("print") { c in
            let separator = c.args.value("separator")?.asString ?? " "
            let items = zip(c.args.values, c.args.labels).filter { $0.1 == nil }.map { $0.0.dereferenced.display }
            c.machine.emitLog(c.fiber, items.joined(separator: separator))
            return .value(.void)
        }))

        // MARK: Assertions
        g.entries["fatalError"] = .value(.native(fn("fatalError") { c in
            throw RuntimeFault(message: "Fatal error: " + (c.args.positional(0)?.display ?? ""))
        }))
        g.entries["preconditionFailure"] = g.entries["fatalError"]
        g.entries["assertionFailure"] = .value(.native(fn("assertionFailure") { c in
            throw RuntimeFault(message: "Assertion failed: " + (c.args.positional(0)?.display ?? ""))
        }))
        for name in ["precondition", "assert"] {
            g.entries[name] = .value(.native(fn(name) { c in
                guard let cond = c.args.positional(0)?.asBool else {
                    throw RuntimeFault(message: "\(name) needs a Bool condition")
                }
                if !cond {
                    let label = name == "assert" ? "Assertion failed" : "Precondition failed"
                    throw RuntimeFault(message: "\(label): " + (c.args.positional(1)?.display ?? ""))
                }
                return .value(.void)
            }))
        }
        g.entries["dispatchPrecondition"] = .value(.native(fn("dispatchPrecondition") { c in
            guard case .tuple(let parts)? = c.args.value("condition"), parts.count == 2,
                  case .string(let kind) = parts[0], case .object(let o) = parts[1], let q = o as? QueueObject else {
                throw RuntimeFault(message: "dispatchPrecondition(condition:) needs .onQueue(q) or .notOnQueue(q)")
            }
            let onIt: Bool
            if q.kind == .main {
                onIt = c.fiber.thread?.kind == .main
            } else if case .dispatch(_, let current) = c.fiber.kind {
                onIt = current === q || q.syncHolders.contains { $0 === c.fiber }
            } else {
                onIt = q.syncHolders.contains { $0 === c.fiber }
            }
            let wantsOn = kind != "notOnQueue"
            if onIt != wantsOn {
                throw RuntimeFault(message: "dispatchPrecondition failed: expected to be \(wantsOn ? "on" : "off") \(q.display)")
            }
            return .value(.void)
        }))
        for name in ["min", "max"] {
            g.entries[name] = .value(.native(fn(name) { c in
                let values = c.args.values.map(\.dereferenced)
                guard var best = values.first else { throw RuntimeFault(message: "\(name) needs arguments") }
                for v in values.dropFirst() {
                    let less = try c.machine.binary("<", v, best)
                    if (name == "min") == (less.asBool ?? false) { best = v }
                }
                return .value(best)
            }))
        }
        g.entries["abs"] = .value(.native(fn("abs") { c in
            switch c.args.positional(0) {
            case .int(let i)?: return .value(.int(abs(i)))
            case .double(let d)?: return .value(.double(abs(d)))
            default: throw RuntimeFault(message: "abs needs a number")
            }
        }))

        // MARK: Dispatch
        let dispatchQueue = type("DispatchQueue")
        dispatchQueue.nativeStatics["main"] = .property { m in .object(m.mainQueue) }
        let globalQueue = fn("DispatchQueue.global") { c in
            let qos = QoS(c.args.value("qos")) ?? .default
            return .value(.object(c.machine.globalQueues[qos]!))
        }
        dispatchQueue.nativeStatics["global"] = .function(globalQueue)
        dispatchQueue.nativeInit = fn("DispatchQueue.init") { c in
            guard let label = c.args.value("label")?.asString else {
                throw RuntimeFault(message: "DispatchQueue(label:) needs a label")
            }
            let attrs = c.args.value("attributes")
            var concurrent = false
            switch attrs {
            case .enumCase(_, "concurrent")?: concurrent = true
            case .array(let items)?: concurrent = items.contains { if case .enumCase(_, "concurrent") = $0 { return true }; return false }
            default: break
            }
            let m = c.machine
            let q = QueueObject(id: m.nextID(), kind: concurrent ? .concurrent : .serial, label: label, qos: QoS(c.args.value("qos")) ?? .default)
            m.queues.append(q)
            return .value(.object(q))
        }
        dispatchQueue.nativeStatics["concurrentPerform"] = .function(fn("DispatchQueue.concurrentPerform") { c in
            guard let n = c.args.value("iterations")?.asInt, let body = c.args.closure("execute") else {
                throw RuntimeFault(message: "concurrentPerform(iterations:execute:) needs both arguments")
            }
            let m = c.machine
            let group = GroupObject(id: m.nextID(), line: c.fiber.userLine)
            let queue = m.globalQueues[.userInitiated]!
            for i in 0..<n {
                group.count += 1
                m.submit(m.makeWork(body, args: [.int(i)], group: group, qos: .userInitiated, line: c.fiber.userLine), to: queue)
            }
            if group.count == 0 { return .value(.void) }
            group.waiters.append(c.fiber)
            return .block(.concurrentPerform, then: { _ in .value(.void) })
        })

        let group = type("DispatchGroup")
        group.nativeInit = fn("DispatchGroup.init") { c in
            let m = c.machine
            let obj = GroupObject(id: m.nextID(), line: c.fiber.userLine)
            m.groups.append(obj)
            return .value(.object(obj))
        }

        let semaphore = type("DispatchSemaphore")
        semaphore.nativeInit = fn("DispatchSemaphore.init") { c in
            guard let v = c.args.value("value")?.asInt, v >= 0 else {
                throw RuntimeFault(message: "DispatchSemaphore(value:) needs a value of 0 or more")
            }
            let m = c.machine
            let obj = SemaphoreObject(id: m.nextID(), value: v, line: c.fiber.userLine)
            m.semaphores.append(obj)
            return .value(.object(obj))
        }

        let workItem = type("DispatchWorkItem")
        workItem.nativeInit = fn("DispatchWorkItem.init") { c in
            guard let block = c.args.closure("block") else {
                throw RuntimeFault(message: "DispatchWorkItem needs a block")
            }
            let flags = c.args.value("flags")
            var barrier = false
            if case .enumCase(_, "barrier")? = flags { barrier = true }
            let m = c.machine
            return .value(.object(WorkItemObject(id: m.nextID(), block: block, qos: QoS(c.args.value("qos")) ?? .default, isBarrier: barrier)))
        }

        let now = fn("DispatchTime.now") { c in .value(.dispatchTime(c.machine.now)) }
        for name in ["DispatchTime", "DispatchWallTime"] {
            let t = type(name)
            t.nativeStatics["now"] = .function(now)
            t.nativeStatics["distantFuture"] = .property { _ in .dispatchTime(.infinity) }
        }
        let qosType = type("DispatchQoS")
        for q in QoS.allCases {
            qosType.nativeStatics[q.rawValue] = .property { _ in .enumCase("DispatchQoS", q.rawValue) }
        }
        let timeoutType = type("DispatchTimeoutResult")
        for r in ["success", "timedOut"] {
            timeoutType.nativeStatics[r] = .property { _ in .enumCase("DispatchTimeoutResult", r) }
        }

        // MARK: Threads and time
        let thread = type("Thread")
        thread.nativeStatics["sleep"] = .function(fn("Thread.sleep") { c in
            guard let d = (c.args.value("forTimeInterval") ?? c.args.positional(0))?.asDouble else {
                throw RuntimeFault(message: "Thread.sleep(forTimeInterval:) needs a number of seconds")
            }
            let m = c.machine
            let f = c.fiber
            f.timerToken = m.addTimer(at: m.now + max(0, d)) { [weak m, weak f] in
                guard let m, let f else { return }
                f.timerToken = nil
                m.wake(f, value: .void)
            }
            return .block(.sleep)
        })
        thread.nativeStatics["isMainThread"] = .property { m in
            .bool(m.currentFiber?.thread?.kind == .main)
        }
        thread.nativeStatics["current"] = .property { m in
            let th = m.currentFiber?.thread
            return .object(ThreadInfoObject(id: m.nextID(), isMain: th?.kind == .main, name: th?.name ?? "?"))
        }

        let date = type("Date")
        date.nativeInit = fn("Date") { c in
            let offset = c.args.value("timeIntervalSinceNow")?.asDouble ?? 0
            return .value(.date(c.machine.now + offset))
        }
        date.nativeStatics["now"] = .property { m in .date(m.now) }

        let duration = type("Duration")
        let units: [(String, Double)] = [("seconds", 1), ("milliseconds", 1e-3), ("microseconds", 1e-6), ("nanoseconds", 1e-9)]
        for (unit, scale) in units {
            let make = fn("Duration.\(unit)") { c in
                guard let v = c.args.positional(0)?.asDouble else {
                    throw RuntimeFault(message: ".\(unit)(_:) needs a number")
                }
                return .value(.duration(v * scale))
            }
            duration.nativeStatics[unit] = .function(make)
            g.implicitMembers[unit] = .value(.native(make))
        }

        // MARK: Swift Concurrency
        let task = type("Task")
        task.nativeInit = fn("Task.init") { c in
            guard let op = c.args.closure("operation") else {
                throw RuntimeFault(message: "Task { } needs a closure")
            }
            let m = c.machine
            let t = try m.startTask(op, priority: TaskPriorityName.rank(c.args.value("priority")), detached: false, childOf: nil, group: nil, inheritIsolation: true, line: c.fiber.userLine)
            return .value(.object(t))
        }
        task.nativeStatics["detached"] = .function(fn("Task.detached") { c in
            guard let op = c.args.closure("operation") else {
                throw RuntimeFault(message: "Task.detached { } needs a closure")
            }
            let m = c.machine
            let t = try m.startTask(op, priority: TaskPriorityName.rank(c.args.value("priority")), detached: true, childOf: nil, group: nil, inheritIsolation: false, line: c.fiber.userLine)
            return .value(.object(t))
        })
        task.nativeStatics["sleep"] = .function(fn("Task.sleep", isAsync: true, throwsFlag: true) { c in
            let seconds: Double
            if case .duration(let d)? = c.args.value("for") {
                seconds = d
            } else if let ns = c.args.value("nanoseconds")?.asDouble {
                seconds = ns / 1_000_000_000
            } else if let s = c.args.positional(0)?.asDouble {
                seconds = s / 1_000_000_000
            } else {
                throw RuntimeFault(message: "Task.sleep needs for: .seconds(…) or nanoseconds:")
            }
            let m = c.machine
            let f = c.fiber
            guard let current = f.task else {
                throw RuntimeFault(message: "Task.sleep can only be awaited inside a Task")
            }
            if current.isCancelled { return .throwError(Machine.cancellationError) }
            f.timerToken = m.addTimer(at: m.now + max(0, seconds)) { [weak m, weak f] in
                guard let m, let f else { return }
                f.timerToken = nil
                m.resumeSuspended(f, .value(.void))
            }
            return .suspend(.sleep)
        })
        task.nativeStatics["yield"] = .function(fn("Task.yield", isAsync: true) { _ in .suspend(.yield) })
        task.nativeStatics["isCancelled"] = .property { m in .bool(m.currentFiber?.task?.isCancelled ?? false) }
        task.nativeStatics["checkCancellation"] = .function(fn("Task.checkCancellation", throwsFlag: true) { c in
            (c.fiber.task?.isCancelled ?? false) ? .throwError(Machine.cancellationError) : .value(.void)
        })
        task.nativeStatics["currentPriority"] = .property { m in
            .enumCase("TaskPriority", TaskPriorityName.name(m.currentFiber?.task?.priority ?? 25))
        }
        let priority = type("TaskPriority")
        for p in ["high", "medium", "low", "userInitiated", "utility", "background"] {
            priority.nativeStatics[p] = .property { _ in .enumCase("TaskPriority", p) }
        }
        let cancellation = type("CancellationError")
        cancellation.nativeInit = fn("CancellationError") { _ in .value(Machine.cancellationError) }

        // MARK: Prelude hooks (not for learners; prefixed with __)
        g.entries["__isGlobalQueue"] = .value(.native(fn("__isGlobalQueue") { c in
            guard case .object(let o)? = c.args.positional(0), let q = o as? QueueObject else { return .value(.bool(false)) }
            return .value(.bool(q.kind == .global))
        }))
        g.entries["__makeContinuation"] = .value(.native(fn("__makeContinuation") { c in
            let m = c.machine
            let cont = ContinuationObject(id: m.nextID(), isThrowing: c.args.positional(0)?.asBool ?? false, line: c.fiber.userLine)
            m.continuations.append(cont)
            return .value(.object(cont))
        }))
        g.entries["__awaitContinuation"] = .value(.native(fn("__awaitContinuation", isAsync: true) { c in
            guard case .object(let o)? = c.args.positional(0), let cont = o as? ContinuationObject else {
                throw RuntimeFault(message: "internal: continuation")
            }
            if let p = cont.pending {
                cont.pending = nil
                return TaskObject.deliver(p, asResult: false)
            }
            cont.waiter = c.fiber
            return .suspend(.continuation(cont))
        }))
        g.entries["__makeTaskGroup"] = .value(.native(fn("__makeTaskGroup") { c in
            let m = c.machine
            return .value(.object(TaskGroupObject(id: m.nextID(), isThrowing: c.args.positional(0)?.asBool ?? false, owner: c.fiber.task)))
        }))

        // MARK: Implicit members (`.main`, `.userInitiated`, `.now()` …)
        g.implicitMembers["main"] = .computed { m in .object(m.mainQueue) }
        g.implicitMembers["global"] = .value(.native(globalQueue))
        g.implicitMembers["now"] = .value(.native(now))
        g.implicitMembers["distantFuture"] = .value(.dispatchTime(.infinity))
        for q in QoS.allCases {
            g.implicitMembers[q.rawValue] = .value(.enumCase("DispatchQoS", q.rawValue))
        }
        for p in ["high", "medium", "low"] {
            g.implicitMembers[p] = .value(.enumCase("TaskPriority", p))
        }
        for name in ["concurrent", "barrier", "initiallyInactive", "detached", "enforceQoS", "inheritQoS"] {
            g.implicitMembers[name] = .value(.enumCase("DispatchFlags", name))
        }
        for r in ["success", "timedOut"] {
            g.implicitMembers[r] = .value(.enumCase("DispatchTimeoutResult", r))
        }
        for kind in ["onQueue", "notOnQueue", "onQueueAsBarrier"] {
            g.implicitMembers[kind] = .value(.native(fn(".\(kind)") { c in
                .value(.tuple([.string(kind), c.args.positional(0) ?? .void]))
            }))
        }
        return g
    }
}
