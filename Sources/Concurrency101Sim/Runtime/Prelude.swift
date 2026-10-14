/// The teaching library, rewritten in the sandbox's Swift subset. Each
/// helper is the same 1:1 mapping onto an Apple API as in
/// `Sources/Concurrency101`, so a learner who runs a teaching snippet in the
/// sandbox exercises the same real call underneath.
///
/// Generics and `@Sendable` annotations are dropped: the simulator is
/// dynamically typed. Swift Concurrency entry points that take a body
/// (`MainActor.run`, `withTaskGroup`, continuations) live here too, written
/// on top of a few `__` hooks.
enum Prelude {
    static let source = #"""
enum Concurrency101 {
    enum GCD {
        static func runForImmediateUI(_ work: @escaping () -> Void) {
            DispatchQueue.global(qos: .userInteractive).async(execute: work)
        }

        static func runUserRequestedWork(_ work: @escaping () -> Void) {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        }

        static func runMaintenanceWork(_ work: @escaping () -> Void) {
            DispatchQueue.global(qos: .utility).async(execute: work)
        }

        static func runWhenUserIsNotWaiting(_ work: @escaping () -> Void) {
            DispatchQueue.global(qos: .background).async(execute: work)
        }

        static func updateUI(_ work: @escaping () -> Void) {
            DispatchQueue.main.async(execute: work)
        }

        static func updateUI(after delay: TimeInterval, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        static func makeCancellableWork(_ work: @escaping () -> Void) -> DispatchWorkItem {
            return DispatchWorkItem(block: work)
        }

        static func makePrivateSerialLane(label: String, qos: DispatchQoS = .unspecified) -> DispatchQueue {
            return DispatchQueue(label: label, qos: qos)
        }

        static func makeSharedConcurrentLane(label: String, qos: DispatchQoS = .unspecified) -> DispatchQueue {
            return DispatchQueue(label: label, qos: qos, attributes: .concurrent)
        }

        static func runOnLane(_ queue: DispatchQueue, _ work: @escaping () -> Void) {
            queue.async(execute: work)
        }

        static func runExclusiveWrite(on queue: DispatchQueue, _ work: @escaping () -> Void) {
            assert(!__isGlobalQueue(queue), "Concurrency101.GCD: barriers on DispatchQueue.global() do not isolate the system concurrent pool. Create a queue with makeSharedConcurrentLane(label:).")
            queue.async(flags: .barrier, execute: work)
        }

        static func runSeveralThenContinue(
            on queue: DispatchQueue = .global(qos: .userInitiated),
            jobs: [() -> Void],
            then finish: @escaping () -> Void,
            finishOn finishQueue: DispatchQueue = .main
        ) {
            let group = DispatchGroup()
            for job in jobs {
                queue.async(group: group, execute: job)
            }
            group.notify(queue: finishQueue, execute: finish)
        }

        final class CompletionCounter {
            let group = DispatchGroup()

            init() {}

            func beginOne() {
                group.enter()
            }

            func endOne() {
                group.leave()
            }

            func whenAllHaveEnded(on queue: DispatchQueue = .main, _ finish: @escaping () -> Void) {
                group.notify(queue: queue, execute: finish)
            }
        }

        enum Blocking {
            static func blockThisThreadUntilFinished(on queue: DispatchQueue, _ work: () -> Void) {
                queue.sync(execute: work)
            }

            static func blockThisThreadUntilAllJobsEnd(_ counter: CompletionCounter, timeout: DispatchTime = .distantFuture) -> DispatchTimeoutResult {
                return counter.group.wait(timeout: timeout)
            }
        }
    }

    enum Modern {
        static func updateUI(_ work: @escaping @MainActor () -> Void) -> Task {
            return Task { @MainActor in
                work()
            }
        }

        static func waitForUI(_ work: @escaping @MainActor () -> T) async -> T {
            return await MainActor.run(body: work)
        }

        static func updateUI(after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) -> Task {
            return Task { @MainActor in
                try? await pauseThisTask(for: delay)
                guard !Task.isCancelled else { return }
                work()
            }
        }

        static func runDetachedFromCaller(_ work: @escaping () async -> Void) -> Task {
            return Task.detached {
                await work()
            }
        }

        static func runForImmediateUI(_ work: @escaping () async -> Void) -> Task {
            return Task(priority: .high) {
                await work()
            }
        }

        static func runUserRequestedWork(_ work: @escaping () async -> Void) -> Task {
            return Task(priority: .userInitiated) {
                await work()
            }
        }

        static func runMaintenanceWork(_ work: @escaping () async -> Void) -> Task {
            return Task(priority: .utility) {
                await work()
            }
        }

        static func runWhenUserIsNotWaiting(_ work: @escaping () async -> Void) -> Task {
            return Task(priority: .background) {
                await work()
            }
        }

        static func makeCancellableWork(_ work: @escaping () async -> Void) -> Task {
            return Task {
                await work()
            }
        }

        static func throwIfCancelled() throws {
            try Task.checkCancellation()
        }

        static var isCurrentTaskCancelled: Bool {
            return Task.isCancelled
        }

        static func pauseThisTask(for seconds: TimeInterval) async throws {
            try await Task.sleep(for: .seconds(seconds))
        }

        static func letOthersRun() async {
            await Task.yield()
        }

        static func waitForCallback(_ body: (CheckedContinuation) -> Void) async -> T {
            return await withCheckedContinuation(body)
        }

        static func waitForThrowingCallback(_ body: (CheckedContinuation) -> Void) async throws -> T {
            return try await withCheckedThrowingContinuation(body)
        }

        static func runSeveralThenContinue(jobs: [() async -> Void], then finish: @escaping () async -> Void) async {
            await withTaskGroup(of: Void.self) { group in
                for job in jobs {
                    group.addTask {
                        await job()
                    }
                }
            }
            await finish()
        }

        static func runTwoAtOnce(_ first: @escaping () async -> A, _ second: @escaping () async -> B) async -> (A, B) {
            async let a = first()
            async let b = second()
            return await (a, b)
        }

        actor ExclusiveState {
            private(set) var value: Value

            init(_ value: Value) {
                self.value = value
            }

            func snapshot() -> Value {
                return value
            }

            func replace(_ newValue: Value) {
                value = newValue
            }

            func modify(_ body: (inout Value) -> Void) {
                body(&value)
            }

            @discardableResult
            func readAwaitWrite(_ body: (Value) async -> Value) async -> Value {
                let current = value
                let next = await body(current)
                value = next
                return next
            }
        }

        enum Blocking {
            static func parkThisThreadUntilTaskFinishes(_ work: @escaping () async -> Void) {
                let gate = DispatchSemaphore(value: 0)
                Task.detached {
                    await work()
                    gate.signal()
                }
                gate.wait()
            }
        }
    }
}

enum MainActor {
    @MainActor
    static func run(resultType: Any = Void.self, body: () throws -> T) async -> T {
        return try body()
    }
}

func withCheckedContinuation(isolation: Any = nil, function: String = #function, _ body: (CheckedContinuation) -> Void) async -> T {
    let continuation = __makeContinuation(false)
    body(continuation)
    return await __awaitContinuation(continuation)
}

func withCheckedThrowingContinuation(isolation: Any = nil, function: String = #function, _ body: (CheckedContinuation) -> Void) async throws -> T {
    let continuation = __makeContinuation(true)
    body(continuation)
    return try await __awaitContinuation(continuation)
}

func withUnsafeContinuation(isolation: Any = nil, _ body: (UnsafeContinuation) -> Void) async -> T {
    let continuation = __makeContinuation(false)
    body(continuation)
    return await __awaitContinuation(continuation)
}

func withUnsafeThrowingContinuation(isolation: Any = nil, _ body: (UnsafeContinuation) -> Void) async throws -> T {
    let continuation = __makeContinuation(true)
    body(continuation)
    return try await __awaitContinuation(continuation)
}

func withTaskGroup(of childTaskResultType: Any = Void.self, returning returnType: Any = Void.self, isolation: Any = nil, body: (inout TaskGroup) async -> Result) async -> Result {
    let group = __makeTaskGroup(false)
    let result = await body(group)
    await group.waitForAll()
    return result
}

func withThrowingTaskGroup(of childTaskResultType: Any = Void.self, returning returnType: Any = Void.self, isolation: Any = nil, body: (inout ThrowingTaskGroup) async throws -> Result) async throws -> Result {
    let group = __makeTaskGroup(true)
    let result = try await body(group)
    try await group.waitForAll()
    return result
}

func withDiscardingTaskGroup(returning returnType: Any = Void.self, isolation: Any = nil, body: (inout DiscardingTaskGroup) async -> Result) async -> Result {
    let group = __makeTaskGroup(false)
    let result = await body(group)
    await group.waitForAll()
    return result
}
"""#
}
