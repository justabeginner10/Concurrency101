/// Base class for heap objects: queues, groups, tasks, instances.
class SimObject {
    let id: Int

    init(id: Int) {
        self.id = id
    }

    var typeName: String { "Object" }
    var display: String { typeName }

    /// A member on this object, or nil when there is none.
    func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        nil
    }
}

struct MemberContext {
    unowned let machine: Machine
    let fiber: Fiber
    let awaited: Bool
}

/// Helper for native methods bound to an object.
func method(_ name: String, isAsync: Bool = false, throwsFlag: Bool = false, _ impl: @escaping (NativeContext) throws -> NativeResult) -> NativeResult {
    .value(.native(NativeFunction(name, isAsync: isAsync, throwsFlag: throwsFlag, impl: impl)))
}

enum QoS: String, CaseIterable {
    case userInteractive
    case userInitiated
    case `default`
    case utility
    case background
    case unspecified

    var rank: Int {
        switch self {
        case .userInteractive: return 33
        case .userInitiated: return 25
        case .default, .unspecified: return 21
        case .utility: return 17
        case .background: return 9
        }
    }

    init?(_ value: Value?) {
        guard let value else { return nil }
        switch value {
        case .enumCase(_, let name), .string(let name):
            guard let q = QoS(rawValue: name) else { return nil }
            self = q
        default:
            return nil
        }
    }
}

enum TaskPriorityName {
    static func rank(_ value: Value?) -> Int? {
        guard let value else { return nil }
        let name: String
        switch value {
        case .enumCase(_, let n), .string(let n): name = n
        case .int(let i): return i
        default: return nil
        }
        switch name {
        case "high", "userInitiated", "userInteractive": return 25
        case "medium", "default": return 21
        case "low", "utility": return 17
        case "background": return 9
        default: return nil
        }
    }

    static func name(_ rank: Int) -> String {
        switch rank {
        case 25...: return "high"
        case 21..<25: return "medium"
        case 17..<21: return "low"
        default: return "background"
        }
    }
}

// MARK: - Dispatch

/// A block submitted to a queue.
final class DispatchWork {
    let callee: Value
    let args: [Value]
    let group: GroupObject?
    let workItem: WorkItemObject?
    let syncWaiter: Fiber?
    let isBarrier: Bool
    let qos: QoS
    let line: Int?
    let seq: Int

    init(callee: Value, args: [Value] = [], group: GroupObject? = nil, workItem: WorkItemObject? = nil, syncWaiter: Fiber? = nil, isBarrier: Bool = false, qos: QoS, line: Int?, seq: Int) {
        self.callee = callee
        self.args = args
        self.group = group
        self.workItem = workItem
        self.syncWaiter = syncWaiter
        self.isBarrier = isBarrier
        self.qos = qos
        self.line = line
        self.seq = seq
    }
}

/// An entry waiting in a queue: a block to run, or a `sync` caller waiting
/// for its turn.
enum QueueEntry {
    case work(DispatchWork)
    case syncGrant(Fiber, isBarrier: Bool, seq: Int, line: Int?)

    var isBarrier: Bool {
        switch self {
        case .work(let w): return w.isBarrier
        case .syncGrant(_, let b, _, _): return b
        }
    }

    var seq: Int {
        switch self {
        case .work(let w): return w.seq
        case .syncGrant(_, _, let s, _): return s
        }
    }
}

final class QueueObject: SimObject {
    enum Kind {
        case main
        case global
        case serial
        case concurrent
    }

    let kind: Kind
    let label: String
    let qos: QoS
    var entries: [QueueEntry] = []
    /// Blocks (or granted sync callers) currently running on this queue.
    var activeCount = 0
    var barrierActive = false
    /// Fibers holding this queue through `sync`.
    var syncHolders: [Fiber] = []
    var runningFibers: [Fiber] = []

    init(id: Int, kind: Kind, label: String, qos: QoS) {
        self.kind = kind
        self.label = label
        self.qos = qos
        super.init(id: id)
    }

    override var typeName: String { "DispatchQueue" }

    override var display: String {
        switch kind {
        case .main: return "main queue"
        case .global: return "global(.\(qos.rawValue))"
        case .serial, .concurrent: return label
        }
    }

    var isCustom: Bool { kind == .serial || kind == .concurrent }

    /// The next entry allowed to start, honoring serial order and barriers.
    func eligibleIndex() -> Int? {
        guard let head = entries.first else { return nil }
        switch kind {
        case .main, .global:
            return 0
        case .serial:
            return activeCount == 0 ? 0 : nil
        case .concurrent:
            if barrierActive { return nil }
            if head.isBarrier { return activeCount == 0 ? 0 : nil }
            return 0
        }
    }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "label": return .value(.string(label))
        case "qos": return .value(.enumCase("DispatchQoS", qos.rawValue))
        case "async":
            return method("DispatchQueue.async") { c in
                try m.dispatchAsync(on: self, c, after: nil)
            }
        case "asyncAfter":
            return method("DispatchQueue.asyncAfter") { c in
                guard let deadline = c.args.value("deadline") ?? c.args.value("wallDeadline") else {
                    throw RuntimeFault(message: "asyncAfter needs a deadline: argument")
                }
                guard case .dispatchTime(let t) = deadline else {
                    throw RuntimeFault(message: "asyncAfter's deadline must be a DispatchTime, like .now() + 0.5")
                }
                return try m.dispatchAsync(on: self, c, after: t)
            }
        case "sync":
            return method("DispatchQueue.sync") { c in
                try m.dispatchSync(on: self, c)
            }
        case "asyncAndWait":
            return method("DispatchQueue.asyncAndWait") { c in
                try m.dispatchSync(on: self, c)
            }
        case "suspend", "resume", "activate", "setSpecific", "getSpecific", "setTarget":
            throw RuntimeFault(message: "DispatchQueue.\(name) isn't modelled in the sandbox yet")
        default:
            return nil
        }
    }
}

final class GroupObject: SimObject {
    var count = 0
    var notifies: [(QueueObject, DispatchWork)] = []
    var waiters: [Fiber] = []
    let line: Int?

    init(id: Int, line: Int?) {
        self.line = line
        super.init(id: id)
    }

    override var typeName: String { "DispatchGroup" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "enter":
            return method("DispatchGroup.enter") { _ in
                self.count += 1
                return .value(.void)
            }
        case "leave":
            return method("DispatchGroup.leave") { _ in
                try m.groupLeave(self)
                return .value(.void)
            }
        case "notify":
            return method("DispatchGroup.notify") { c in
                guard let queueValue = c.args.value("queue") else {
                    throw RuntimeFault(message: "group.notify needs queue:, for example notify(queue: .main)")
                }
                let queue = try m.queueArgument(queueValue)
                let callee: Value
                var item: WorkItemObject?
                if let w = c.args.value("work"), case .object(let o) = w, let wi = o as? WorkItemObject {
                    callee = wi.block
                    item = wi
                } else if let closure = c.args.closure("execute") {
                    if case .object(let o) = closure, let wi = o as? WorkItemObject {
                        callee = wi.block
                        item = wi
                    } else {
                        callee = closure
                    }
                } else {
                    throw RuntimeFault(message: "group.notify needs a block to run")
                }
                let work = m.makeWork(callee, workItem: item, qos: queue.qos, line: m.currentLine(c.fiber))
                self.notifies.append((queue, work))
                if self.count == 0 { m.groupReachedZero(self) }
                return .value(.void)
            }
        case "wait":
            return method("DispatchGroup.wait") { c in
                let timeout = c.args.value("timeout") ?? c.args.value("wallTimeout")
                if self.count == 0 {
                    return .value(timeout == nil ? .void : .enumCase("DispatchTimeoutResult", "success"))
                }
                return m.blockWithTimeout(c.fiber, reason: .groupWait(self), timeout: timeout) {
                    self.waiters.removeAll { $0 === c.fiber }
                }
            }
        default:
            return nil
        }
    }
}

final class SemaphoreObject: SimObject {
    var value: Int
    let initial: Int
    var waiters: [Fiber] = []
    let line: Int?

    init(id: Int, value: Int, line: Int?) {
        self.value = value
        self.initial = value
        self.line = line
        super.init(id: id)
    }

    override var typeName: String { "DispatchSemaphore" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "wait":
            return method("DispatchSemaphore.wait") { c in
                let timeout = c.args.value("timeout") ?? c.args.value("wallTimeout")
                self.value -= 1
                if self.value >= 0 {
                    return .value(timeout == nil ? .void : .enumCase("DispatchTimeoutResult", "success"))
                }
                self.waiters.append(c.fiber)
                return m.blockWithTimeout(c.fiber, reason: .semaphore(self), timeout: timeout) {
                    self.value += 1
                    self.waiters.removeAll { $0 === c.fiber }
                }
            }
        case "signal":
            return method("DispatchSemaphore.signal") { _ in
                self.value += 1
                if !self.waiters.isEmpty {
                    let f = self.waiters.removeFirst()
                    m.wake(f, value: .enumCase("DispatchTimeoutResult", "success"))
                    return .value(.int(1))
                }
                return .value(.int(0))
            }
        default:
            return nil
        }
    }
}

final class WorkItemObject: SimObject {
    let block: Value
    let qos: QoS
    let isBarrier: Bool
    var isCancelled = false
    var isDone = false
    var notifies: [(QueueObject, DispatchWork)] = []
    var waiters: [Fiber] = []

    init(id: Int, block: Value, qos: QoS, isBarrier: Bool) {
        self.block = block
        self.qos = qos
        self.isBarrier = isBarrier
        super.init(id: id)
    }

    override var typeName: String { "DispatchWorkItem" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "isCancelled":
            return .value(.bool(isCancelled))
        case "cancel":
            return method("DispatchWorkItem.cancel") { _ in
                self.isCancelled = true
                return .value(.void)
            }
        case "perform":
            return method("DispatchWorkItem.perform") { _ in
                if self.isCancelled {
                    return .value(.void)
                }
                return .call(self.block, Arguments(values: [], labels: [], trailingStart: 0), then: { _ in
                    m.workItemFinished(self)
                    return .value(.void)
                })
            }
        case "notify":
            return method("DispatchWorkItem.notify") { c in
                guard let queueValue = c.args.value("queue") else {
                    throw RuntimeFault(message: "workItem.notify needs queue:")
                }
                let queue = try m.queueArgument(queueValue)
                guard let closure = c.args.closure("execute") else {
                    throw RuntimeFault(message: "workItem.notify needs a block to run")
                }
                let work = m.makeWork(closure, qos: queue.qos, line: m.currentLine(c.fiber))
                if self.isDone {
                    m.submit(work, to: queue)
                } else {
                    self.notifies.append((queue, work))
                }
                return .value(.void)
            }
        case "wait":
            return method("DispatchWorkItem.wait") { c in
                if self.isDone {
                    return .value(c.args.value("timeout") == nil ? .void : .enumCase("DispatchTimeoutResult", "success"))
                }
                self.waiters.append(c.fiber)
                return m.blockWithTimeout(c.fiber, reason: .workItemWait(self), timeout: c.args.value("timeout")) {
                    self.waiters.removeAll { $0 === c.fiber }
                }
            }
        default:
            return nil
        }
    }
}

// MARK: - Swift Concurrency

final class TaskObject: SimObject {
    var fiber: Fiber?
    var priority: Int
    var isCancelled = false
    var result: ResumePayload?
    var awaiters: [Fiber] = []
    var children: [TaskObject] = []
    weak var parent: TaskObject?
    weak var group: TaskGroupObject?
    let isDetached: Bool
    let line: Int?
    let number: Int

    init(id: Int, number: Int, priority: Int, isDetached: Bool, line: Int?) {
        self.number = number
        self.priority = priority
        self.isDetached = isDetached
        self.line = line
        super.init(id: id)
    }

    override var typeName: String { "Task" }
    override var display: String { "Task #\(number)" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "cancel":
            return method("Task.cancel") { _ in
                m.cancel(self)
                return .value(.void)
            }
        case "isCancelled":
            return .value(.bool(isCancelled))
        case "value", "result":
            if !ctx.awaited {
                throw RuntimeFault(message: "reading task.\(name) is async: write 'await task.\(name)'")
            }
            let wantsResult = name == "result"
            if let result {
                return Self.deliver(result, asResult: wantsResult)
            }
            awaiters.append(ctx.fiber)
            return .suspend(.taskValue(self), then: wantsResult ? nil : nil)
        default:
            return nil
        }
    }

    static func deliver(_ result: ResumePayload, asResult: Bool) -> NativeResult {
        switch result {
        case .value(let v): return .value(v)
        case .error(let e): return asResult ? .value(e) : .throwError(e)
        }
    }
}

final class TaskGroupObject: SimObject {
    let isThrowing: Bool
    var running: [TaskObject] = []
    var completed: [ResumePayload] = []
    var nextWaiter: Fiber?
    var allWaiter: Fiber?
    var isCancelled = false
    weak var owner: TaskObject?

    init(id: Int, isThrowing: Bool, owner: TaskObject?) {
        self.isThrowing = isThrowing
        self.owner = owner
        super.init(id: id)
    }

    override var typeName: String { "TaskGroup" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "addTask", "addTaskUnlessCancelled":
            let unlessCancelled = name == "addTaskUnlessCancelled"
            return method("TaskGroup.\(name)") { c in
                guard let op = c.args.closure("operation") else {
                    throw RuntimeFault(message: "group.addTask needs a closure")
                }
                if unlessCancelled && self.isCancelled {
                    return .value(.bool(false))
                }
                let priority = TaskPriorityName.rank(c.args.value("priority"))
                _ = try m.startTask(op, priority: priority, detached: false, childOf: c.fiber.task, group: self, inheritIsolation: false, line: m.currentLine(c.fiber))
                return .value(unlessCancelled ? .bool(true) : .void)
            }
        case "next":
            return method("TaskGroup.next", isAsync: true, throwsFlag: isThrowing) { c in
                if !self.completed.isEmpty {
                    let r = self.completed.removeFirst()
                    return TaskObject.deliver(r, asResult: false)
                }
                if self.running.isEmpty {
                    return .value(.nilValue)
                }
                self.nextWaiter = c.fiber
                return .suspend(.groupNext(self), then: nil)
            }
        case "waitForAll":
            return method("TaskGroup.waitForAll", isAsync: true, throwsFlag: isThrowing) { c in
                if self.running.isEmpty {
                    return self.drainForWaitAll()
                }
                self.allWaiter = c.fiber
                return .suspend(.groupWaitAll(self), then: { _ in self.drainForWaitAll() })
            }
        case "cancelAll":
            return method("TaskGroup.cancelAll") { _ in
                self.isCancelled = true
                self.running.forEach { m.cancel($0) }
                return .value(.void)
            }
        case "isEmpty":
            return .value(.bool(running.isEmpty && completed.isEmpty))
        case "isCancelled":
            return .value(.bool(isCancelled))
        default:
            return nil
        }
    }

    private func drainForWaitAll() -> NativeResult {
        let results = completed
        completed.removeAll()
        if isThrowing {
            for case .error(let e) in results {
                return .throwError(e)
            }
        }
        return .value(.void)
    }
}

final class ContinuationObject: SimObject {
    let isThrowing: Bool
    var resumed = false
    var pending: ResumePayload?
    var waiter: Fiber?
    let line: Int?

    init(id: Int, isThrowing: Bool, line: Int?) {
        self.isThrowing = isThrowing
        self.line = line
        super.init(id: id)
    }

    override var typeName: String { isThrowing ? "CheckedContinuation<_, Error>" : "CheckedContinuation" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "resume":
            return method("CheckedContinuation.resume") { c in
                if self.resumed {
                    throw RuntimeFault(message: "SWIFT TASK CONTINUATION MISUSE: the continuation was resumed more than once")
                }
                self.resumed = true
                let payload: ResumePayload
                if let e = c.args.value("throwing") {
                    payload = .error(e)
                } else if let v = c.args.value("returning") {
                    payload = .value(v)
                } else if let r = c.args.value("with") {
                    payload = .value(r)
                } else {
                    payload = .value(.void)
                }
                if let waiter = self.waiter {
                    self.waiter = nil
                    m.resumeSuspended(waiter, payload)
                } else {
                    self.pending = payload
                }
                return .value(.void)
            }
        default:
            return nil
        }
    }
}

final class AsyncLetHandle: SimObject {
    let task: TaskObject
    let name: String

    init(id: Int, task: TaskObject, name: String) {
        self.task = task
        self.name = name
        super.init(id: id)
    }

    override var typeName: String { "async let" }
}

// MARK: - Language objects

/// An instance of a user (or prelude) class or actor.
final class InstanceObject: SimObject {
    let type: TypeObject
    var fields: [String: Box] = [:]
    var initializing = true
    /// The fiber currently running on this actor.
    weak var owner: Fiber?
    var waitingJobs = 0

    init(id: Int, type: TypeObject) {
        self.type = type
        super.init(id: id)
        for field in type.fields {
            fields[field.name] = Box(.uninitialized, name: field.name)
        }
    }

    override var typeName: String { type.name }
    override var display: String { type.isActor ? "actor \(type.name)" : type.name }
}

final class IteratorObject: SimObject {
    enum Source {
        case range(Int, Int)
        case array([Value])
        case group(TaskGroupObject)
    }

    let source: Source
    var index = 0

    init(id: Int, source: Source) {
        self.source = source
        super.init(id: id)
    }

    override var typeName: String { "Iterator" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        guard name == "next" else { return nil }
        switch source {
        case .range(let lo, let hi):
            return method("next") { _ in
                let v = lo + self.index
                guard v < hi else { return .value(.nilValue) }
                self.index += 1
                return .value(.int(v))
            }
        case .array(let items):
            return method("next") { _ in
                guard self.index < items.count else { return .value(.nilValue) }
                self.index += 1
                return .value(items[self.index - 1])
            }
        case .group(let g):
            return try g.member("next", ctx)
        }
    }
}

/// The `log` object every snippet writes to.
final class LogObject: SimObject {
    override var typeName: String { "DemoLog" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        let m = ctx.machine
        switch name {
        case "log":
            return method("log.log") { c in
                let text = c.args.values.map { $0.dereferenced.display }.joined(separator: " ")
                m.emitLog(c.fiber, text)
                return .value(.void)
            }
        case "clear":
            return method("log.clear") { _ in .value(.void) }
        default:
            return nil
        }
    }
}

/// `Thread.current`.
final class ThreadInfoObject: SimObject {
    let isMain: Bool
    let name: String

    init(id: Int, isMain: Bool, name: String) {
        self.isMain = isMain
        self.name = name
        super.init(id: id)
    }

    override var typeName: String { "Thread" }
    override var display: String { "<Thread: \(name)>" }

    override func member(_ name: String, _ ctx: MemberContext) throws -> NativeResult? {
        switch name {
        case "isMainThread": return .value(.bool(isMain))
        case "name": return .value(.string(self.name))
        default: return nil
        }
    }
}
