import Dispatch

extension Concurrency101.GCD {
    /// Creates a private FIFO lane where only one block runs at a time.
    ///
    /// This is queue *confinement*: one isolation domain for mutable state.
    /// It is the GCD version of an `actor`.
    ///
    /// The caller waits: **no** (this only constructs a queue).
    ///
    /// GCD: `DispatchQueue(label:qos:)` with no `.concurrent` attribute.
    ///
    /// Swift Concurrency: `actor`.
    ///
    /// Use when: one object’s mutable state must not be accessed from two
    /// closures at once.
    ///
    /// Do not use when: independent jobs should overlap. Serial will bottleneck.
    ///
    /// The returned value is a real `DispatchQueue` on purpose. Graduation
    /// means calling `async` / `sync` on it yourself.
    ///
    /// `qos` is optional classification for *work on this lane*, not a thread
    /// assignment. Prefer `.unspecified` (inherit) unless you know the user
    /// intent of everything that will run here. Do not stamp `.userInteractive`
    /// on a cache lane.
    ///
    /// Label with reverse-DNS, unique per purpose:
    /// `com.concurrency101.example.counter`.
    ///
    /// ```swift
    /// let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.example.counter")
    /// Concurrency101.GCD.runOnLane(lane) { count += 1 }
    /// ```
    ///
    /// - Parameters:
    ///   - label: Unique reverse-DNS name shown in Instruments.
    ///   - qos: Quality of service for the lane. Default inherits.
    /// - Returns: A serial `DispatchQueue` you own.
    ///
    /// - SeeAlso: ``Concurrency101/GCD/runOnLane(_:_:)``, ``Concurrency101/GCD/makeSharedConcurrentLane(label:qos:)``
    /// - SeeAlso: [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
    public static func makePrivateSerialLane(
        label: String,
        qos: DispatchQoS = .unspecified
    ) -> DispatchQueue {
        DispatchQueue(label: label, qos: qos)
    }

    /// Creates a private FIFO *submission* lane that may run several blocks at once.
    ///
    /// Concurrent is not “faster.” It means submitted items **may overlap**.
    /// Unsynchronized mutation on this lane is a data race.
    ///
    /// The caller waits: **no** (this only constructs a queue).
    ///
    /// GCD: `DispatchQueue(label:qos:attributes: .concurrent)`.
    ///
    /// Swift Concurrency: overlapping `Task`s or a task group — without a
    /// queue object.
    ///
    /// Use when: independent work items, or a reader-writer pattern with
    /// ``Concurrency101/GCD/runExclusiveWrite(on:_:)``.
    ///
    /// Do not use when: you need mutual exclusion. Use
    /// ``Concurrency101/GCD/makePrivateSerialLane(label:qos:)`` or an actor.
    ///
    /// ```swift
    /// let lane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.example.thumbs")
    /// Concurrency101.GCD.runOnLane(lane) { makeThumb(a) }
    /// Concurrency101.GCD.runOnLane(lane) { makeThumb(b) }
    /// ```
    ///
    /// - Parameters:
    ///   - label: Unique reverse-DNS name shown in Instruments.
    ///   - qos: Quality of service for the lane. Default inherits.
    /// - Returns: A concurrent `DispatchQueue` you own.
    public static func makeSharedConcurrentLane(
        label: String,
        qos: DispatchQoS = .unspecified
    ) -> DispatchQueue {
        DispatchQueue(label: label, qos: qos, attributes: .concurrent)
    }

    /// Submits `work` on `queue` and returns immediately.
    ///
    /// This is `async`. The caller continues. On a **serial** lane, items still
    /// run one at a time in FIFO submission order. On a **concurrent** lane,
    /// they may overlap.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `queue.async(execute:)`
    ///
    /// Swift Concurrency: hop isolation (`await actor.method()`,
    /// `MainActor.run`) — not a perfect 1:1.
    ///
    /// ```swift
    /// let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.example.serial")
    /// Concurrency101.GCD.runOnLane(lane) { stepOne() }
    /// Concurrency101.GCD.runOnLane(lane) { stepTwo() } // after stepOne on a serial lane
    /// ```
    ///
    /// - Parameters:
    ///   - queue: A queue you created, or another `DispatchQueue`.
    ///   - work: Work to enqueue.
    public static func runOnLane(_ queue: DispatchQueue, _ work: @escaping () -> Void) {
        queue.async(execute: work)
    }

    /// On a *custom concurrent* queue, runs `work` after in-flight items
    /// finish, overlapping nothing else on that queue until `work` returns.
    /// Then ordinary concurrent items resume.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `queue.async(flags: .barrier, execute:)`
    ///
    /// Swift Concurrency: an `actor`, or a lock around the write. Barriers are
    /// a GCD-specific reader-writer trick.
    ///
    /// Use when: many concurrent reads, rare writes, on a queue **you** created
    /// with ``Concurrency101/GCD/makeSharedConcurrentLane(label:qos:)``.
    ///
    /// Do not use when: the queue is `DispatchQueue.global()`. Barriers on the
    /// system concurrent pool do **not** give you exclusive access.
    ///
    /// Teaching trap (interview classic): `async(flags: .barrier)` on a global
    /// queue is effectively a regular async.
    ///
    /// ```swift
    /// let cacheLane = Concurrency101.GCD.makeSharedConcurrentLane(label: "com.concurrency101.example.cache")
    /// Concurrency101.GCD.runOnLane(cacheLane) { _ = cache[key] }           // read
    /// Concurrency101.GCD.runExclusiveWrite(on: cacheLane) { cache[key] = v } // write
    /// ```
    ///
    /// Footgun:
    ///
    /// ```swift
    /// Concurrency101.GCD.runExclusiveWrite(on: .global()) { /* not exclusive */ }
    /// ```
    ///
    /// In DEBUG builds this method asserts if `queue` is a system global queue.
    ///
    /// - Parameters:
    ///   - queue: A custom concurrent queue.
    ///   - work: Exclusive work (typically a write).
    ///
    /// - SeeAlso: [DispatchWorkItemFlags.barrier](https://developer.apple.com/documentation/dispatch/dispatchworkitemflags/barrier)
    public static func runExclusiveWrite(on queue: DispatchQueue, _ work: @escaping () -> Void) {
        #if DEBUG
        assert(
            !GlobalQueueIdentity.matches(queue),
            "Concurrency101.GCD: barriers on DispatchQueue.global() do not isolate the system concurrent pool. Create a queue with makeSharedConcurrentLane(label:)."
        )
        #endif
        queue.async(flags: .barrier, execute: work)
    }
}
