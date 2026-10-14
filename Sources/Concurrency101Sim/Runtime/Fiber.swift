/// One activation of a function. Native frames hold no code: they receive
/// the value a callee returns and decide what happens next.
final class Frame {
    let closure: Closure?
    let proto: FunctionProto?
    var pc = 0
    var stack: [Value] = []
    var slots: [Box?]
    var handlers: [(pc: Int, depth: Int)] = []
    var defers: [Closure] = []
    var pending: Completion?
    /// The executor this frame runs on.
    var executor: Executor
    let nativeThen: ((Value) throws -> NativeResult)?

    enum Completion {
        case returning(Value)
        case throwing(Value)
    }

    init(closure: Closure, executor: Executor) {
        self.closure = closure
        self.proto = closure.proto
        self.slots = Array(repeating: nil, count: closure.proto.localCount)
        self.executor = executor
        self.nativeThen = nil
    }

    init(then: @escaping (Value) throws -> NativeResult, executor: Executor) {
        self.closure = nil
        self.proto = nil
        self.slots = []
        self.executor = executor
        self.nativeThen = then
    }

    var isNative: Bool { nativeThen != nil }
}

enum ResumePayload {
    case value(Value)
    case error(Value)
}

/// Why a fiber is holding its thread without running.
enum BlockReason {
    case sleep
    case semaphore(SemaphoreObject)
    case groupWait(GroupObject)
    case queueSync(QueueObject)
    case mainSync
    case workItemWait(WorkItemObject)
    case concurrentPerform

    var api: String {
        switch self {
        case .sleep: return "Thread.sleep"
        case .semaphore: return "DispatchSemaphore.wait()"
        case .groupWait: return "DispatchGroup.wait()"
        case .queueSync(let q): return "\(q.label).sync"
        case .mainSync: return "DispatchQueue.main.sync"
        case .workItemWait: return "DispatchWorkItem.wait()"
        case .concurrentPerform: return "DispatchQueue.concurrentPerform"
        }
    }
}

/// Why a task gave its thread back.
enum SuspendReason {
    case sleep
    case yield
    case taskValue(TaskObject)
    case asyncLet(TaskObject)
    case groupNext(TaskGroupObject)
    case groupWaitAll(TaskGroupObject)
    case continuation(ContinuationObject)

    var api: String {
        switch self {
        case .sleep: return "Task.sleep"
        case .yield: return "Task.yield()"
        case .taskValue: return "await task.value"
        case .asyncLet: return "await on an async let"
        case .groupNext: return "await group.next()"
        case .groupWaitAll: return "waiting for a task group's children"
        case .continuation: return "a continuation"
        }
    }
}

enum FiberState {
    case queued
    case running
    case blocked(BlockReason)
    case suspended(SuspendReason)
    case finished
}

/// A thread of execution in the simulator: a dispatched block, a task,
/// or the button action that starts the program.
final class Fiber {
    enum Kind {
        case entry
        case dispatch(DispatchWork, QueueObject)
        case task(TaskObject)
    }

    let id: Int
    let kind: Kind
    var frames: [Frame] = []
    var state: FiberState = .queued
    weak var thread: SimThread?
    var executor: Executor
    var resume: ResumePayload?
    /// Read-modify-write bookkeeping for lost-update detection.
    var rmw: [(Box, Int)] = []
    var timerToken: Int?
    let createdLine: Int?

    init(id: Int, kind: Kind, executor: Executor, createdLine: Int?) {
        self.id = id
        self.kind = kind
        self.executor = executor
        self.createdLine = createdLine
    }

    var task: TaskObject? {
        if case .task(let t) = kind { return t }
        return nil
    }

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }

    var blockReason: BlockReason? {
        if case .blocked(let r) = state { return r }
        return nil
    }

    var suspendReason: SuspendReason? {
        if case .suspended(let r) = state { return r }
        return nil
    }

    /// The learner's line this fiber is on: the innermost frame that is not
    /// prelude code (so a hang inside `blockThisThreadUntilFinished` points
    /// at the learner's call, not the helper's body).
    var userLine: Int? {
        for (i, frame) in frames.enumerated().reversed() {
            guard let proto = frame.proto, !proto.isPrelude, !proto.lines.isEmpty else { continue }
            let isTop = i == frames.count - 1
            let index = isTop ? min(frame.pc, proto.lines.count - 1) : max(0, min(frame.pc - 1, proto.lines.count - 1))
            return proto.lines[index]
        }
        return createdLine
    }
}

final class SimThread {
    enum Kind {
        case main
        case gcd
        case cooperative
    }

    let id: Int
    let name: String
    let kind: Kind
    var fiber: Fiber?
    /// Ticks left before a freshly started job runs (dispatch latency).
    var delay = 0
    var segments: [SegmentRecord] = []
    var open: (start: Double, label: String, blocked: Bool, line: Int?)?

    init(id: Int, name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    var isIdle: Bool { fiber == nil }

    var isRunning: Bool {
        guard let f = fiber else { return false }
        if case .running = f.state { return true }
        return false
    }

    var isBlocked: Bool {
        fiber?.blockReason != nil
    }
}

struct SegmentRecord {
    var start: Double
    var end: Double
    var label: String
    var blocked: Bool
    var line: Int?
    var unfinished: Bool
}
