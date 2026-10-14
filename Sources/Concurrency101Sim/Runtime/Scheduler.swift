extension Machine {
    // MARK: - Run loop

    enum StopReason {
        case idle
        case stepLimit
        case timeLimit
        case crashed
    }

    /// Runs the program the way a button tap would: the entry function is
    /// the first job on the main thread.
    func run(entry: FunctionProto) -> StopReason {
        let f = Fiber(id: nextID(), kind: .entry, executor: .main, createdLine: 1)
        fibers.append(f)
        do {
            _ = try callClosure(f, Closure(proto: entry, upvalues: [], selfValue: nil, isolation: .main), .empty, awaited: false)
        } catch let fault as RuntimeFault {
            crash = (fault.message, 1, "main")
            return .crashed
        } catch {
            return .crashed
        }
        mainLane.append(.resume(f))

        while true {
            do {
                try fireDueTimers()
                try assignThreads()
            } catch let fault as RuntimeFault {
                crash = (fault.message, nil, "main")
                return .crashed
            } catch {
                return .crashed
            }
            if crash != nil { return .crashed }

            let active = threads.filter { $0.isRunning }
            if active.isEmpty {
                if let next = timers.first {
                    now = max(now, next.time)
                    if now > config.maxTime { return .timeLimit }
                    continue
                }
                return .idle
            }

            var order = active
            if order.count > 1 {
                for i in stride(from: order.count - 1, to: 0, by: -1) {
                    order.swapAt(i, rng.int(0...i))
                }
            }
            for th in order {
                guard let f = th.fiber, case .running = f.state else { continue }
                if th.delay > 0 {
                    th.delay -= 1
                    continue
                }
                if active.count > 1 && rng.unit() > speed(of: f) {
                    continue
                }
                do {
                    let outcome = try step(f)
                    try handle(outcome, f, th)
                } catch let fault as RuntimeFault {
                    crash = (fault.message, f.userLine, th.name)
                    return .crashed
                } catch {
                    crash = ("\(error)", f.userLine, th.name)
                    return .crashed
                }
                if crash != nil { return .crashed }
            }
            currentFiber = nil
            now += quantum
            if steps > config.maxSteps { return .stepLimit }
            if now > config.maxTime { return .timeLimit }
        }
    }

    static let wakeUpTicks = 20

    /// Chance a running thread makes progress this tick. Background work
    /// runs slower, the way the OS throttles it.
    private func speed(of f: Fiber) -> Double {
        switch f.kind {
        case .dispatch(let w, _): return w.qos == .background ? 0.45 : 0.85
        case .task(let t): return t.priority <= 9 ? 0.45 : 0.85
        case .entry: return 0.85
        }
    }

    private func handle(_ outcome: StepOutcome, _ f: Fiber, _ th: SimThread) throws {
        switch outcome {
        case .continued:
            break
        case .blocked:
            switchSegment(th, blocked: true, label: f.blockReason?.api ?? "blocked", line: f.userLine)
        case .suspended:
            detach(f, th)
            if case .suspended(.yield) = f.state {
                enqueueResume(f, f.executor)
            }
        case .hopped(let target):
            detach(f, th)
            enqueueResume(f, target)
        case .finished(let result):
            detach(f, th)
            f.state = .finished
            try fiberFinished(f, result)
        }
    }

    // MARK: - Threads

    private func spawnThread(_ kind: SimThread.Kind) -> SimThread {
        let th = SimThread(id: threads.count, name: "T\(threads.count)", kind: kind)
        threads.append(th)
        if kind == .gcd { gcdThreads.append(th) } else { coopThreads.append(th) }
        return th
    }

    private func attach(_ f: Fiber, _ th: SimThread) {
        th.fiber = f
        f.thread = th
        f.state = .running
        // A worker that picks up a job takes a moment to get going (thread
        // wake-up, cache misses). The jitter is what lets unsynchronized
        // `+=` from different workers overlap, as they do on a device.
        th.delay = th.kind == .main ? 0 : rng.int(0...Self.wakeUpTicks)
        if case .actor(let a) = f.executor { a.owner = f }
        openSegment(th, label: contextLabel(f), blocked: false, line: f.userLine)
    }

    private func detach(_ f: Fiber, _ th: SimThread) {
        closeSegment(th)
        th.fiber = nil
        f.thread = nil
        if case .actor(let a) = f.executor, a.owner === f { a.owner = nil }
    }

    func contextLabel(_ f: Fiber) -> String {
        switch f.kind {
        case .entry:
            return "button action"
        case .dispatch(_, let q):
            return q.display
        case .task(let t):
            switch f.executor {
            case .main: return "MainActor · task \(t.number)"
            case .pool: return "task \(t.number)"
            case .actor(let a): return "\(a.display) · task \(t.number)"
            case .dispatch(let q): return q.display
            }
        }
    }

    private func assignThreads() throws {
        grantSyncWaiters()

        if mainThread.isIdle, !mainLane.isEmpty {
            switch mainLane.removeFirst() {
            case .work(let w):
                if let f = try makeDispatchFiber(w, mainQueue) { attach(f, mainThread) }
            case .resume(let f):
                f.executor = .main
                attach(f, mainThread)
            }
        }

        for th in gcdThreads where th.isIdle {
            guard let (q, i) = pickGCDWork() else { break }
            try startGCD(th, q, i)
        }
        while gcdThreads.count < 64, let (q, i) = pickGCDWork(),
              gcdThreads.filter({ !$0.isIdle && !$0.isBlocked }).count < config.cores {
            if let idle = gcdThreads.first(where: { $0.isIdle }) {
                try startGCD(idle, q, i)
            } else {
                try startGCD(spawnThread(.gcd), q, i)
            }
        }

        for th in coopThreads where th.isIdle {
            guard let j = pickCoopJob() else { break }
            startCoop(th, j)
        }
        while coopThreads.count < config.cores, let j = pickCoopJob() {
            startCoop(spawnThread(.cooperative), j)
        }
    }

    private func grantSyncWaiters() {
        for q in queues where q.isCustom {
            while let i = q.eligibleIndex(), case .syncGrant(let f, let barrier, _, _) = q.entries[i] {
                q.entries.remove(at: i)
                q.activeCount += 1
                if barrier { q.barrierActive = true }
                q.syncHolders.append(f)
                wake(f, value: .void)
            }
        }
    }

    private func pickGCDWork() -> (QueueObject, Int)? {
        var best: (QueueObject, Int, Int, Int)?
        for q in queues {
            guard let i = q.eligibleIndex(), case .work(let w) = q.entries[i] else { continue }
            let rank = w.qos.rank
            if let b = best {
                if rank > b.2 || (rank == b.2 && w.seq < b.3) { best = (q, i, rank, w.seq) }
            } else {
                best = (q, i, rank, w.seq)
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    private func startGCD(_ th: SimThread, _ q: QueueObject, _ i: Int) throws {
        guard case .work(let w) = q.entries.remove(at: i) else { return }
        q.activeCount += 1
        if w.isBarrier { q.barrierActive = true }
        if let f = try makeDispatchFiber(w, q) {
            q.runningFibers.append(f)
            attach(f, th)
        }
    }

    private func makeDispatchFiber(_ w: DispatchWork, _ q: QueueObject) throws -> Fiber? {
        if let item = w.workItem, item.isCancelled {
            try completeWork(w, q, .value(.void), fiber: nil)
            return nil
        }
        let f = Fiber(id: nextID(), kind: .dispatch(w, q), executor: q.kind == .main ? .main : .dispatch(q), createdLine: w.line)
        fibers.append(f)
        guard case .closure(let c) = w.callee.dereferenced else {
            throw RuntimeFault(message: "a DispatchQueue block must be a closure")
        }
        _ = try callClosure(f, c, Arguments(values: w.args, labels: w.args.map { _ in nil }, trailingStart: w.args.count), awaited: false)
        return f
    }

    private func pickCoopJob() -> Int? {
        var best: Int?
        for (i, job) in coopJobs.enumerated() {
            if case .actor(let a) = job.executor, a.owner != nil { continue }
            if let b = best {
                let other = coopJobs[b]
                if job.priority > other.priority || (job.priority == other.priority && job.seq < other.seq) { best = i }
            } else {
                best = i
            }
        }
        return best
    }

    private func startCoop(_ th: SimThread, _ index: Int) {
        let job = coopJobs.remove(at: index)
        job.fiber.executor = job.executor
        attach(job.fiber, th)
    }

    func enqueueResume(_ f: Fiber, _ executor: Executor) {
        f.state = .queued
        switch executor {
        case .main:
            mainLane.append(.resume(f))
        case .pool, .actor:
            coopJobs.append(CoopJob(fiber: f, executor: executor, priority: f.task?.priority ?? 21, seq: nextSeq()))
        case .dispatch:
            crash = ("internal: a task can't resume on a dispatch queue", f.userLine, "?")
        }
    }

    // MARK: - Timers

    @discardableResult
    func addTimer(at time: Double, _ action: @escaping () throws -> Void) -> Int {
        let seq = nextSeq()
        let entry = TimerEntry(time: time, seq: seq, action: action)
        var lo = 0
        var hi = timers.count
        while lo < hi {
            let mid = (lo + hi) / 2
            let t = timers[mid]
            if t.time < time || (t.time == time && t.seq < seq) { lo = mid + 1 } else { hi = mid }
        }
        timers.insert(entry, at: lo)
        return seq
    }

    func cancelTimer(_ token: Int) {
        if let i = timers.firstIndex(where: { $0.seq == token }) {
            timers.remove(at: i)
        }
    }

    private func fireDueTimers() throws {
        while let first = timers.first, first.time <= now + 1e-12 {
            timers.removeFirst()
            try first.action()
        }
    }

    // MARK: - Waking

    func wake(_ f: Fiber, value: Value) {
        guard case .blocked = f.state else { return }
        if let token = f.timerToken {
            cancelTimer(token)
            f.timerToken = nil
        }
        f.resume = .value(value)
        f.state = .running
        if let th = f.thread {
            switchSegment(th, blocked: false, label: contextLabel(f), line: f.userLine)
        }
    }

    func resumeSuspended(_ f: Fiber, _ payload: ResumePayload) {
        guard case .suspended = f.state else { return }
        if let token = f.timerToken {
            cancelTimer(token)
            f.timerToken = nil
        }
        f.resume = payload
        enqueueResume(f, f.executor)
    }

    /// Blocks the calling thread, optionally until a DispatchTime timeout.
    func blockWithTimeout(_ f: Fiber, reason: BlockReason, timeout: Value?, onTimeout: @escaping () -> Void) -> NativeResult {
        if let timeout, case .dispatchTime(let t) = timeout, t.isFinite {
            f.timerToken = addTimer(at: max(t, now)) { [weak self, weak f] in
                guard let self, let f, f.blockReason != nil else { return }
                onTimeout()
                f.timerToken = nil
                self.wake(f, value: .enumCase("DispatchTimeoutResult", "timedOut"))
            }
        }
        return .block(reason)
    }

    // MARK: - Dispatch

    func makeWork(_ callee: Value, args: [Value] = [], group: GroupObject? = nil, workItem: WorkItemObject? = nil, syncWaiter: Fiber? = nil, isBarrier: Bool = false, qos: QoS, line: Int?) -> DispatchWork {
        DispatchWork(callee: callee, args: args, group: group, workItem: workItem, syncWaiter: syncWaiter, isBarrier: isBarrier, qos: qos, line: line, seq: nextSeq())
    }

    func submit(_ work: DispatchWork, to queue: QueueObject) {
        if queue.kind == .main {
            mainLane.append(.work(work))
        } else {
            queue.entries.append(.work(work))
        }
    }

    func currentLine(_ f: Fiber) -> Int? {
        f.userLine
    }

    func queueArgument(_ v: Value) throws -> QueueObject {
        if case .object(let o) = v.dereferenced, let q = o as? QueueObject { return q }
        throw RuntimeFault(message: "expected a DispatchQueue, found \(v.dereferenced.typeName)")
    }

    private func hasBarrierFlag(_ v: Value?) -> Bool {
        switch v?.dereferenced {
        case .enumCase(_, "barrier")?: return true
        case .array(let items)?: return items.contains { if case .enumCase(_, "barrier") = $0 { return true }; return false }
        default: return false
        }
    }

    private func blockArgument(_ c: NativeContext) throws -> (Value, WorkItemObject?) {
        guard let exec = c.args.closure("execute") ?? c.args.value("work") else {
            throw RuntimeFault(message: "\(c.name) needs a block to run")
        }
        if case .object(let o) = exec, let item = o as? WorkItemObject {
            return (item.block, item)
        }
        guard case .closure = exec.dereferenced else {
            throw RuntimeFault(message: "\(c.name) needs a closure, found \(exec.dereferenced.typeName)")
        }
        return (exec, nil)
    }

    func dispatchAsync(on queue: QueueObject, _ c: NativeContext, after deadline: Double?) throws -> NativeResult {
        let (callee, item) = try blockArgument(c)
        var group: GroupObject?
        if let g = c.args.value("group") {
            guard case .object(let o) = g, let go = o as? GroupObject else {
                throw RuntimeFault(message: "group: needs a DispatchGroup")
            }
            group = go
        }
        var barrier = hasBarrierFlag(c.args.value("flags")) || (item?.isBarrier ?? false)
        if barrier && queue.kind != .concurrent {
            if queue.kind == .global {
                emitWarning(c.fiber, "The .barrier flag is ignored on a global queue: it only isolates a queue you created with attributes: .concurrent.")
            }
            barrier = false
        }
        let qos = QoS(c.args.value("qos")) ?? item?.qos ?? (queue.qos == .unspecified ? .default : queue.qos)
        group?.count += 1
        let work = makeWork(callee, group: group, workItem: item, isBarrier: barrier, qos: qos, line: c.fiber.userLine)
        if let deadline {
            addTimer(at: max(deadline, now)) { [weak self] in self?.submit(work, to: queue) }
        } else {
            submit(work, to: queue)
        }
        return .value(.void)
    }

    func dispatchSync(on queue: QueueObject, _ c: NativeContext) throws -> NativeResult {
        let (callee, item) = try blockArgument(c)
        if let item, item.isCancelled { return .value(.void) }
        let finishItem: (Value) -> Void = { [weak self] _ in
            if let item { self?.workItemFinished(item) }
        }
        switch queue.kind {
        case .main:
            let work = makeWork(callee, workItem: item, syncWaiter: c.fiber, qos: .userInteractive, line: c.fiber.userLine)
            mainLane.append(.work(work))
            return .block(.mainSync)
        case .global:
            return .call(callee, .empty, then: { v in
                finishItem(v)
                return .value(v)
            })
        case .serial, .concurrent:
            let barrier = queue.kind == .concurrent && hasBarrierFlag(c.args.value("flags"))
            queue.entries.append(.syncGrant(c.fiber, isBarrier: barrier, seq: nextSeq(), line: c.fiber.userLine))
            let fiber = c.fiber
            return .block(.queueSync(queue), then: { [weak self] _ in
                .call(callee, .empty, then: { v in
                    self?.releaseSync(queue, fiber, barrier: barrier)
                    finishItem(v)
                    return .value(v)
                })
            })
        }
    }

    private func releaseSync(_ q: QueueObject, _ f: Fiber, barrier: Bool) {
        q.activeCount -= 1
        if barrier { q.barrierActive = false }
        if let i = q.syncHolders.firstIndex(where: { $0 === f }) { q.syncHolders.remove(at: i) }
    }

    private func completeWork(_ w: DispatchWork, _ q: QueueObject, _ result: ResumePayload, fiber: Fiber?) throws {
        if q.kind != .main {
            q.activeCount -= 1
            if w.isBarrier { q.barrierActive = false }
            if let fiber { q.runningFibers.removeAll { $0 === fiber } }
        }
        if case .error(let e) = result {
            throw RuntimeFault(message: "an error escaped a DispatchQueue block: \(e.display)")
        }
        if let item = w.workItem { workItemFinished(item) }
        if let g = w.group { try groupLeave(g) }
        if let waiter = w.syncWaiter, case .value(let v) = result {
            wake(waiter, value: v)
        }
    }

    func workItemFinished(_ item: WorkItemObject) {
        item.isDone = true
        let notifies = item.notifies
        item.notifies.removeAll()
        for (q, w) in notifies { submit(w, to: q) }
        let waiters = item.waiters
        item.waiters.removeAll()
        for f in waiters { wake(f, value: .enumCase("DispatchTimeoutResult", "success")) }
    }

    func groupLeave(_ g: GroupObject) throws {
        g.count -= 1
        if g.count < 0 {
            throw RuntimeFault(message: "Unbalanced call to dispatch_group_leave(): leave() was called more times than enter()")
        }
        if g.count == 0 { groupReachedZero(g) }
    }

    func groupReachedZero(_ g: GroupObject) {
        let notifies = g.notifies
        g.notifies.removeAll()
        for (q, w) in notifies { submit(w, to: q) }
        let waiters = g.waiters
        g.waiters.removeAll()
        for f in waiters { wake(f, value: .enumCase("DispatchTimeoutResult", "success")) }
    }

    // MARK: - Tasks

    /// Starts a task. `inheritIsolation` is true for `Task { }`, which runs
    /// where its closure was written (the main actor, an actor), and false
    /// for detached tasks and child tasks, which run on the pool.
    @discardableResult
    func startTask(_ op: Value, priority: Int?, detached: Bool, childOf parent: TaskObject?, group: TaskGroupObject?, inheritIsolation: Bool, line: Int?) throws -> TaskObject {
        guard case .closure(let c) = op.dereferenced else {
            throw RuntimeFault(message: "a Task needs a closure")
        }
        let executor: Executor
        if c.proto.isolationRule == .main {
            executor = .main
        } else if inheritIsolation {
            executor = c.isolation.executor ?? .pool
        } else {
            executor = .pool
        }
        let creator = currentFiber
        let inherited: Int
        if let t = creator?.task {
            inherited = t.priority
        } else if case .dispatch(let w, _)? = creator?.kind {
            inherited = w.qos.rank
        } else {
            inherited = 25
        }
        taskCounter += 1
        let task = TaskObject(id: nextID(), number: taskCounter, priority: priority ?? (detached ? 21 : inherited), isDetached: detached, line: line)
        let f = Fiber(id: nextID(), kind: .task(task), executor: executor, createdLine: line)
        task.fiber = f
        if let parent, !detached {
            task.parent = parent
            parent.children.append(task)
            if parent.isCancelled { task.isCancelled = true }
        }
        if let group {
            task.group = group
            group.running.append(task)
            if group.isCancelled { task.isCancelled = true }
        }
        tasks.append(task)
        fibers.append(f)
        let outcome = try callClosure(f, c, .empty, awaited: true)
        if case .hopped(let target) = outcome {
            enqueueResume(f, target)
        } else {
            enqueueResume(f, executor)
        }
        return task
    }

    func cancel(_ t: TaskObject) {
        if t.isCancelled { return }
        t.isCancelled = true
        t.children.forEach(cancel)
        if let f = t.fiber, case .suspended(.sleep) = f.state {
            resumeSuspended(f, .error(Self.cancellationError))
        }
    }

    static let cancellationError = Value.error("CancellationError", "CancellationError()")

    private func fiberFinished(_ f: Fiber, _ result: ResumePayload) throws {
        switch f.kind {
        case .entry:
            if case .error(let e) = result {
                throw RuntimeFault(message: "uncaught error: \(e.display)")
            }
        case .dispatch(let w, let q):
            try completeWork(w, q, result, fiber: f)
        case .task(let t):
            completeTask(t, result)
        }
    }

    private func completeTask(_ t: TaskObject, _ result: ResumePayload) {
        t.result = result
        let awaiters = t.awaiters
        t.awaiters.removeAll()
        for a in awaiters { resumeSuspended(a, result) }
        if let g = t.group {
            g.running.removeAll { $0 === t }
            if let w = g.nextWaiter {
                g.nextWaiter = nil
                resumeSuspended(w, result)
            } else {
                g.completed.append(result)
            }
            if g.running.isEmpty, let w = g.allWaiter {
                g.allWaiter = nil
                resumeSuspended(w, .value(.void))
            }
        }
    }

    // MARK: - Output

    func emitLog(_ f: Fiber, _ text: String) {
        guard events.count < Self.maxEvents else {
            eventsTruncated = true
            return
        }
        let th = f.thread
        events.append(SimEvent(
            id: events.count,
            time: now,
            thread: th?.name ?? "?",
            threadID: th?.id ?? -1,
            isMainThread: th?.kind == .main,
            context: contextLabel(f),
            text: text,
            line: f.userLine,
            kind: .log
        ))
    }

    func emitWarning(_ f: Fiber, _ text: String) {
        guard warningsSeen.insert(text).inserted, events.count < Self.maxEvents else { return }
        let th = f.thread
        events.append(SimEvent(
            id: events.count,
            time: now,
            thread: th?.name ?? "?",
            threadID: th?.id ?? -1,
            isMainThread: th?.kind == .main,
            context: contextLabel(f),
            text: text,
            line: f.userLine,
            kind: .warning
        ))
    }

    func recordLostUpdate(_ name: String, line: Int?) {
        var entry = lostUpdates[name] ?? (0, line)
        entry.count += 1
        lostUpdates[name] = entry
    }

    // MARK: - Timeline

    private func openSegment(_ th: SimThread, label: String, blocked: Bool, line: Int?) {
        th.open = (now, label, blocked, line)
    }

    private func closeSegment(_ th: SimThread, unfinished: Bool = false) {
        guard let open = th.open else { return }
        th.open = nil
        let end = max(now, open.start)
        if let last = th.segments.last, last.label == open.label, last.blocked == open.blocked, abs(last.end - open.start) < 1e-9 {
            th.segments[th.segments.count - 1].end = end
            th.segments[th.segments.count - 1].unfinished = unfinished
            return
        }
        th.segments.append(SegmentRecord(start: open.start, end: end, label: open.label, blocked: open.blocked, line: open.line, unfinished: unfinished))
    }

    private func switchSegment(_ th: SimThread, blocked: Bool, label: String, line: Int?) {
        closeSegment(th)
        openSegment(th, label: label, blocked: blocked, line: line)
    }

    func closeAllSegments() {
        for th in threads { closeSegment(th, unfinished: true) }
    }

    func lanes() -> [SimLane] {
        threads.map { th in
            let kind: SimLane.Kind
            switch th.kind {
            case .main: kind = .main
            case .gcd: kind = .gcd
            case .cooperative: kind = .cooperative
            }
            return SimLane(
                id: th.id,
                name: th.name,
                kind: kind,
                segments: th.segments.map {
                    SimSegment(start: $0.start, end: $0.end, label: $0.label, isBlocked: $0.blocked, line: $0.line, unfinished: $0.unfinished)
                }
            )
        }
    }

    // MARK: - Diagnosis

    var hasStuckWork: Bool {
        if !mainLane.isEmpty || !coopJobs.isEmpty { return true }
        if queues.contains(where: { !$0.entries.isEmpty }) { return true }
        return fibers.contains { $0.blockReason != nil }
    }

    /// Explains why nothing can run any more.
    func stallReport() -> SimStall {
        var details: [String] = []
        var lines: [Int] = []
        let blocked = threads.compactMap { th -> (SimThread, Fiber, BlockReason)? in
            guard let f = th.fiber, let r = f.blockReason else { return nil }
            return (th, f, r)
        }
        for (th, f, r) in blocked {
            let where_ = f.userLine.map { " (line \($0))" } ?? ""
            details.append("\(th.name == "main" ? "The main thread" : "Thread \(th.name)") is blocked in \(r.api)\(where_).")
            if let l = f.userLine { lines.append(l) }
        }
        let mainBlocked = mainThread.fiber?.blockReason
        if mainBlocked != nil, !mainLane.isEmpty {
            let jobs = mainLane.prefix(3).map { job -> String in
                switch job {
                case .work(let w): return "a main-queue block" + (w.line.map { " from line \($0)" } ?? "")
                case .resume(let f):
                    let what = f.task.map { "task \($0.number)" } ?? "work"
                    return "\(what) waiting to run on the main actor" + (f.userLine.map { " (line \($0))" } ?? "")
                }
            }
            details.append("Queued for the main thread, and never able to start: \(jobs.joined(separator: "; ")).")
        }
        for q in queues where q.isCustom && !q.entries.isEmpty {
            details.append("Queue '\(q.label)' has \(q.entries.count) item(s) waiting behind a block that never finishes.")
        }
        let coopBlocked = coopThreads.filter { $0.isBlocked }
        if !coopJobs.isEmpty && !coopThreads.isEmpty && coopBlocked.count == coopThreads.count && coopThreads.count >= config.cores {
            details.append("All \(coopThreads.count) cooperative threads are blocked, so the \(coopJobs.count) task job(s) queued for them can't start.")
        }
        for t in tasks {
            guard let f = t.fiber, let r = f.suspendReason else { continue }
            details.append("Task \(t.number)\(t.line.map { " (line \($0))" } ?? "") is suspended in \(r.api).")
        }

        let headline: String
        if case .mainSync? = mainBlocked {
            headline = "Deadlock: DispatchQueue.main.sync was called on the main thread. It waits for the main queue, and only the main thread can run the main queue."
        } else if mainBlocked != nil && !mainLane.isEmpty {
            headline = "Deadlock: the main thread is blocked, and the work that would unblock it is queued to run on the main thread."
        } else if let selfSync = blocked.first(where: { _, f, r in
            if case .queueSync(let q) = r { return q.runningFibers.contains { $0 === f } || q.syncHolders.contains { $0 === f } }
            return false
        }), case .queueSync(let q) = selfSync.2 {
            headline = "Deadlock: a block running on serial queue '\(q.label)' called \(q.label).sync. It waits for the queue, and the queue waits for it."
        } else if !coopJobs.isEmpty && !coopThreads.isEmpty && coopBlocked.count == coopThreads.count && coopThreads.count >= config.cores {
            headline = "Thread-pool starvation: every cooperative thread is blocked, so the tasks that would unblock them never get a thread."
        } else if let first = blocked.first {
            headline = "Hang: \(first.0.name == "main" ? "the main thread" : "thread \(first.0.name)") is blocked in \(first.2.api) and nothing left can wake it."
        } else {
            headline = "Stuck: work is queued but nothing can run it."
        }
        return SimStall(headline: headline, details: details, lines: Array(Set(lines)).sorted(), mainThreadFrozen: mainBlocked != nil)
    }

    /// Things worth knowing about a run. When the run stalled, the stall
    /// report already covers blocked and unfinished work.
    func notes(stalled: Bool) -> [SimNote] {
        var notes: [SimNote] = []
        for (name, entry) in lostUpdates.sorted(by: { $0.key < $1.key }) {
            notes.append(SimNote(
                kind: .warning,
                text: "Data race on '\(name)': \(entry.count) update(s) were lost. Two threads read the same value, and each wrote back its own +1.",
                line: entry.line
            ))
        }
        for g in groups where g.count > 0 && !g.notifies.isEmpty {
            notes.append(SimNote(
                kind: .warning,
                text: "A DispatchGroup notify never ran: the group is still waiting on \(g.count) leave() call(s).",
                line: g.notifies.first?.1.line ?? g.line
            ))
        }
        for c in continuations where !c.resumed {
            notes.append(SimNote(
                kind: .warning,
                text: "A continuation was never resumed, so the task waiting on it never finished.",
                line: c.line
            ))
        }
        for t in tasks where !stalled {
            guard let f = t.fiber, !f.isFinished else { continue }
            if case .continuation? = f.suspendReason { continue }
            let state: String
            if let r = f.suspendReason { state = "still suspended in \(r.api)" } else if let r = f.blockReason { state = "still blocked in \(r.api)" } else { state = "still waiting for a thread" }
            notes.append(SimNote(kind: .info, text: "Task \(t.number) didn't finish: it is \(state).", line: t.line))
        }
        for s in semaphores where !s.waiters.isEmpty && !stalled {
            notes.append(SimNote(kind: .warning, text: "A DispatchSemaphore still has \(s.waiters.count) waiter(s) that were never signalled.", line: s.line))
        }
        if eventsTruncated {
            notes.append(SimNote(kind: .info, text: "Only the first \(Self.maxEvents) log lines were kept.", line: nil))
        }
        return notes
    }
}
