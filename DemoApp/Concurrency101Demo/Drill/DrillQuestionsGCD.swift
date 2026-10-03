enum DrillQuestionsGCD {
    static let all: [DrillQuestion] = easy + medium + hard

    private static let easy: [DrillQuestion] = [
        DrillQuestion(
            id: "gcd.easy.queue-not-thread",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "GCD Mental Model and Architecture",
            stem: "What is a dispatch queue?",
            options: [
                "A logical ordering and scheduling context for work items",
                "A dedicated OS thread permanently bound to that queue",
                "A lock you take around shared mutable state",
                "A guarantee that the closure starts immediately",
            ],
            explanation: "Except for the main queue, a queue is not a thread. GCD maps items onto worker threads. Serial vs concurrent is a property of the queue, not how many threads it owns."
        ),
        DrillQuestion(
            id: "gcd.easy.serial-width",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "Dispatch Queues — Serial, Concurrent, Main, and Global",
            stem: "What does “serial” mean for a dispatch queue?",
            options: [
                "At most one of this queue's items runs at a time",
                "Work always runs off the main thread",
                "The caller never waits",
                "Items on other serial queues cannot overlap with it",
            ],
            explanation: "Serial is per queue. Two different serial queues may overlap with each other. async vs sync is a separate question (whether the caller waits)."
        ),
        DrillQuestion(
            id: "gcd.easy.async-vs-sync",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "async, sync, Ordering, and Execution Semantics",
            stem: "queue.async versus queue.sync answers which question?",
            options: [
                "Must the caller wait until the submitted work finishes?",
                "Is the target queue serial or concurrent?",
                "Will this run on the main thread?",
                "Will GCD create a new thread?",
            ],
            explanation: "Queue type (overlap) and submission (async/sync) are independent. sync blocks the calling thread. async enqueues and returns."
        ),
        DrillQuestion(
            id: "gcd.easy.main-queue",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "Dispatch Queues — Serial, Concurrent, Main, and Global",
            stem: "The main queue is:",
            options: [
                "Serial, and executed on the main thread / main run loop",
                "Concurrent, so UI updates can overlap",
                "Just DispatchQueue.global(qos: .userInteractive)",
                "Safe to sync onto from work that is already on main",
            ],
            explanation: "Main is a serial queue tied to the main thread. main.sync from main deadlocks. Global queues are concurrent and are not the UI queue."
        ),
        DrillQuestion(
            id: "gcd.easy.qos-intent",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "Quality of Service (QoS) and Priority",
            stem: "Quality of Service on a GCD queue is:",
            options: [
                "Scheduling intent and importance, not a deadline",
                "A guaranteed start time",
                "A correctness tool that prevents data races",
                "A 1:1 mapping from that queue to one core",
            ],
            explanation: "QoS tells the system how latency-sensitive the work is. It does not promise when the work runs, and it does not isolate state."
        ),
        DrillQuestion(
            id: "gcd.easy.group-job",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "DispatchGroup, DispatchWorkItem, and DispatchSemaphore",
            stem: "What is DispatchGroup for?",
            options: [
                "Tracking when a set of operations have all completed",
                "Blocking a thread until a resource slot opens",
                "Cancelling every block you submitted",
                "Forcing completion in submission order",
            ],
            explanation: "A group counts membership (enter/leave or async(group:)). notify is asynchronous. A semaphore is a blocking counter. Neither cancels work."
        ),
        DrillQuestion(
            id: "gcd.easy.async-not-concurrent",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "async, sync, Ordering, and Execution Semantics",
            stem: "serialQueue.async { A() }; serialQueue.async { B() } — can A and B overlap?",
            options: [
                "No. Serial forbids overlap; async only means the caller did not wait",
                "Yes. async always means concurrent",
                "Only if they have different QoS",
                "Only if the queue's label contains “serial”",
            ],
            explanation: "async is “caller does not wait.” Concurrent is “this queue may overlap its own items.” On a serial queue, A and B still run one at a time, in submission order."
        ),
        DrillQuestion(
            id: "gcd.easy.sync-not-background",
            track: .gcd,
            difficulty: .easy,
            sourceNote: "async, sync, Ordering, and Execution Semantics",
            stem: "The main thread calls DispatchQueue.global().sync { slowParse() }. Is the UI responsive while slowParse runs?",
            options: [
                "No. sync blocks the caller, even when the target is a background queue",
                "Yes. Global queues always keep main free",
                "It deadlocks",
                "GCD moves slowParse to the next run-loop turn and returns",
            ],
            explanation: "Destination queue ≠ caller stays free. sync from main leaves main blocked until the closure returns. Use async (or Swift await) if the user should still be able to tap."
        ),
    ]

    private static let medium: [DrillQuestion] = [
        DrillQuestion(
            id: "gcd.med.main-sync-deadlock",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "Race Conditions, Deadlocks, Thread Explosion, and Debugging",
            stem: "This action is already running on the main queue. What happens?",
            snippet: """
            @IBAction func tap() {
                DispatchQueue.main.sync {
                    label.text = "hi"
                }
            }
            """,
            options: [
                "Deadlock — the current item waits for a new main-queue item that cannot start",
                "\"hi\" is assigned and the function returns",
                "GCD detects the same-queue sync and runs the closure inline",
                "The assignment is deferred to the next run-loop turn",
            ],
            explanation: "The main queue is serial. The button's item is the current item. sync waits for the new item to finish, but that item cannot start until the current one finishes."
        ),
        DrillQuestion(
            id: "gcd.med.concurrent-fifo",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "async, sync, Ordering, and Execution Semantics",
            stem: "A concurrent queue is FIFO. What is actually guaranteed?",
            options: [
                "Items are dequeued in submission order; they may still overlap and finish in any order",
                "Items complete in submission order",
                "Only one item runs at a time",
                "A later item cannot start until every earlier item has finished",
            ],
            explanation: "FIFO is dequeue order, not completion order and not “serial.” Overlap is the point of a concurrent queue."
        ),
        DrillQuestion(
            id: "gcd.med.barrier-where",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "Protecting Shared State — Serial Queues and Barriers",
            stem: "A barrier gives reader/writer isolation when you:",
            options: [
                "Submit it to a custom concurrent queue you own",
                "Submit it to DispatchQueue.global()",
                "Submit it to DispatchQueue.main",
                "Call sync on any serial queue",
            ],
            explanation: "Barriers are for a private concurrent queue. Global queues are a shared pool; a barrier there does not isolate your readers and writers. Serial queues already have width one — they do not use barriers for that."
        ),
        DrillQuestion(
            id: "gcd.med.workitem-cancel",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "DispatchGroup, DispatchWorkItem, and DispatchSemaphore",
            stem: "item.cancel() is called while the work item's closure is already running. What happens?",
            options: [
                "Cancellation state is set; the running closure is not stopped",
                "The thread is killed",
                "Nested URLSession work is cancelled automatically",
                "GCD rolls back any mutations the closure already made",
            ],
            explanation: "Work-item cancellation is cooperative, like Task.cancel(). Already-executing work keeps going unless it checks item.isCancelled and returns."
        ),
        DrillQuestion(
            id: "gcd.med.group-timeout",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "DispatchGroup, DispatchWorkItem, and DispatchSemaphore",
            stem: "group.wait(timeout: .now() + 2) returns .timedOut. The grouped closures?",
            options: [
                "Keep running. Timeout only stops waiting",
                "Are cancelled",
                "Are removed from their queues",
                "Will never fire notify, even if they later finish",
            ],
            explanation: "Timeout is about the waiter. The work is independent. notify still runs when membership hits zero. Timeout also does not cancel anything."
        ),
        DrillQuestion(
            id: "gcd.med.two-serial-queues",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "Dispatch Queues — Serial, Concurrent, Main, and Global",
            stem: "queueA and queueB are two different custom serial queues. May taskA and taskB run at the same time?",
            snippet: """
            queueA.async { taskA() }
            queueB.async { taskB() }
            """,
            options: [
                "Yes. Serial is per queue, not process-wide",
                "No. All serial queues share one worker",
                "Only if both queues use .userInitiated",
                "Only if one of them targets main",
            ],
            explanation: "Independence of queues is how GCD gets overlap without a concurrent queue. State isolated on queueA is not protected from queueB."
        ),
        DrillQuestion(
            id: "gcd.med.queue-bypass",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "Protecting Shared State — Serial Queues and Barriers",
            stem: "A class isolates var store behind a private serial queue, but one method reads store directly. That read is:",
            options: [
                "A data race waiting to happen — the queue only protects accesses that go through it",
                "Fine, because the property is private",
                "Fine, because the queue's label documents the contract",
                "Fine if that method is called only from main",
            ],
            explanation: "Queue confinement is a discipline, not a compiler-checked isolation domain. private stops other types, not other threads. One bypass voids the scheme."
        ),
        DrillQuestion(
            id: "gcd.med.check-then-act",
            track: .gcd,
            difficulty: .medium,
            sourceNote: "Protecting Shared State — Serial Queues and Barriers",
            stem: "Each call is serialized. Is the pair safe?",
            snippet: """
            if queue.sync({ store.contains(id) }) {
                queue.sync { store.removeValue(forKey: id) }
            }
            """,
            options: [
                "No. Another item can run between the two syncs; the whole workflow must be one item",
                "Yes. Two serial syncs compose into one atomic operation",
                "Yes if you switch both to async",
                "Yes if store is a Swift Dictionary",
            ],
            explanation: "That is a race condition even when each access is race-free. Protect the invariant (removeValue in one sync), not each line."
        ),
    ]

    private static let hard: [DrillQuestion] = [
        DrillQuestion(
            id: "gcd.hard.barrier-on-global",
            track: .gcd,
            difficulty: .hard,
            sourceNote: "Protecting Shared State — Serial Queues and Barriers",
            stem: "DispatchQueue.global().async(flags: .barrier) { mutate() } alongside other .async work on global(). Do you get exclusive access to your state?",
            options: [
                "No. Global queues are a shared system pool; barriers are not a private reader/writer lock there",
                "Yes. A barrier is exclusive on any concurrent queue",
                "Yes for that QoS class, exclusive against all other apps' global work too",
                "It deadlocks",
            ],
            explanation: "Barrier isolation requires a private concurrent queue you control. Using the global concurrent queue as if it were your lock is a classic false sense of safety."
        ),
        DrillQuestion(
            id: "gcd.hard.thread-explosion",
            track: .gcd,
            difficulty: .hard,
            sourceNote: "Race Conditions, Deadlocks, Thread Explosion, and Debugging",
            stem: "Many items on a concurrent queue each semaphore.wait() for a slow resource. What is the failure mode?",
            options: [
                "Blocked workers can cause the system to spawn more threads (thread explosion)",
                "GCD preempts the blocked closures so the pool stays small",
                "The semaphore cancels excess items",
                "QoS is automatically lowered until the waits return",
            ],
            explanation: "GCD's pool is not a cooperative Swift task pool. Blocking a concurrent worker often makes the system create another thread so other items can run. Bound the concurrency; do not wait in unbounded async work."
        ),
        DrillQuestion(
            id: "gcd.hard.wait-on-main",
            track: .gcd,
            difficulty: .hard,
            sourceNote: "DispatchGroup, DispatchWorkItem, and DispatchSemaphore",
            stem: "The main thread calls group.wait(). The grouped work completes by hopping back to main (a main-queue callback). What happens?",
            options: [
                "Deadlock — main is blocked, so the hop back to main cannot run",
                "The wait times out and the UI recovers",
                "GCD reroutes the callback onto a global queue",
                "Fine, because the group itself was created off main",
            ],
            explanation: "Never wait on main. Waiting for work that must run on main is a deadlock. Waiting for anything else still freezes the UI. Use notify (or async/await)."
        ),
        DrillQuestion(
            id: "gcd.hard.actor-vs-serial",
            track: .gcd,
            difficulty: .hard,
            sourceNote: "GCD and Modern Swift Concurrency",
            stem: "You replace a serial isolation queue with an actor. Which difference actually bites?",
            options: [
                "Actor methods can interleave at await (reentrancy). A serial-queue item runs its closure to completion",
                "Actors block a thread the way queue.sync does",
                "Actors do not serialize access; you still need a lock",
                "Serial queues are compiler-checked; actors are not",
            ],
            explanation: "Both serialize. The actor's compiler check is the upgrade. The downgrade is reentrancy: after await download(), another load on the same actor may have run. Queue code that assumed “I am the only closure until I return” does not port unchanged."
        ),
        DrillQuestion(
            id: "gcd.hard.group-vs-semaphore",
            track: .gcd,
            difficulty: .hard,
            sourceNote: "DispatchGroup, DispatchWorkItem, and DispatchSemaphore",
            stem: "You need “run these three network callbacks, then update UI.” Which is the GCD tool, and why not the other?",
            options: [
                "DispatchGroup + notify(queue: .main) — completion tracking without blocking a thread. A semaphore wait on main would freeze or deadlock",
                "DispatchSemaphore(value: 0) on main — that is how you bridge callbacks",
                "Three nested main.sync calls",
                "A barrier on DispatchQueue.global()",
            ],
            explanation: "Group answers “when have they all finished?” with notify, which is async. Semaphore answers “block this thread until a signal.” Bridging callback APIs with wait is the hang you then spend an afternoon on. Prefer a group here, or a continuation in Swift."
        ),
        DrillQuestion(
            id: "gcd.hard.isolation-not-qos",
            track: .gcd,
            difficulty: .hard,
            sourceNote: "Quality of Service (QoS) and Priority",
            stem: "Two closures mutate the same array. One is .userInteractive, one is .background. Is that enough to make it safe?",
            options: [
                "No. QoS is scheduling intent. It does not isolate memory",
                "Yes. Higher QoS always runs to completion first",
                "Yes if both use DispatchQueue.global()",
                "Yes if you add asyncAfter to the background one",
            ],
            explanation: "Priority is not a lock. The notes are explicit: do not “fix” a race with sleeps, priorities, or log order. One isolation domain (serial queue, barrier queue, actor, or lock)."
        ),
    ]
}
