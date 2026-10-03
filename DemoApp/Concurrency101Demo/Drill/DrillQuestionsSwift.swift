enum DrillQuestionsSwift {
    static let all: [DrillQuestion] = easy + medium + hard

    private static let easy: [DrillQuestion] = [
        DrillQuestion(
            id: "sw.easy.isolation-is-static",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Isolation — The Core Concept",
            stem: "Isolation is:",
            options: [
                "A compile-time property of a declaration",
                "Determined by which thread called you",
                "A flag you set by wrapping work in Task { }",
                "Another name for Sendable",
            ],
            explanation: "Same function, same isolation, whoever calls it. “I called it from main so it runs on main” is false. Sendable is what may cross a domain, not where code runs."
        ),
        DrillQuestion(
            id: "sw.easy.three-domains",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Decision Procedure",
            stem: "Every Swift declaration is exactly one of:",
            options: [
                "Main-actor-isolated, actor-isolated, or nonisolated",
                "Async, sync, or detached",
                "Serial, concurrent, or global",
                "Sendable, unchecked, or locked",
            ],
            explanation: "@MainActor is a global actor (kind: actor-isolated, process-wide, main thread). A custom actor is per instance. nonisolated is protected by nothing."
        ),
        DrillQuestion(
            id: "sw.easy.await-vs-task",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Decision Procedure",
            stem: "await foo() versus Task { await foo() }:",
            options: [
                "await waits for the result; Task { } starts unstructured work and the next line runs immediately",
                "They are equivalent",
                "Task { } is structured and waits for foo",
                "await always hops to a background thread",
            ],
            explanation: "await preserves order, errors, and the return value. Task { } is for entering async from sync (a tap). It swallows errors unless you handle them inside. It is not how you leave the main actor."
        ),
        DrillQuestion(
            id: "sw.easy.actor-what",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Actors",
            stem: "An actor:",
            options: [
                "Owns its mutable state and runs isolated work one job at a time",
                "Runs all of its methods in parallel on the main thread",
                "Locks the instance across await, so invariants cannot change",
                "Lets non-Sendable classes cross in and out freely",
            ],
            explanation: "Serial executor plus compiler-enforced access. Values that leave still need to be Sendable. And actors are reentrant at await — that is the next question, not this one."
        ),
        DrillQuestion(
            id: "sw.easy.cancel-is-a-flag",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Tasks, Cancellation and Priority",
            stem: "task.cancel():",
            options: [
                "Sets a flag. Work continues until it checks, or hits a cancellation-aware API",
                "Kills the thread",
                "Injects an exception into the running function immediately",
                "Stops a CPU loop that never reads Task.isCancelled",
            ],
            explanation: "Cooperative, same idea as DispatchWorkItem.cancel(). Task.sleep and URLSession tied to the task will throw. A tight for loop will not, unless you checkCancellation()."
        ),
        DrillQuestion(
            id: "sw.easy.sendable-means",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Sendable and Data-Race Safety",
            stem: "Sendable means:",
            options: [
                "It is safe for this value to be used from more than one isolation domain at a time",
                "The type is a class",
                "The function runs off the main actor",
                "The compiler will make a mutable class safe by copying it",
            ],
            explanation: "Marker protocol: copied, immutable, or internally synchronized. A mutable class shared across domains is the data race Sendable exists to refuse."
        ),
        DrillQuestion(
            id: "sw.easy.structured",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Structured Concurrency",
            stem: "“Structured” concurrency means:",
            options: [
                "A child task's lifetime is bounded by a syntactic scope; the parent cannot return until children finish",
                "You used Task { }",
                "You used GCD groups",
                "Every function is async",
            ],
            explanation: "async let and task groups are structured. Task { } / Task.detached are unstructured — they escape the scope, and you own errors, cancellation, and lifetime yourself."
        ),
        DrillQuestion(
            id: "sw.easy.sequential-await",
            track: .modern,
            difficulty: .easy,
            sourceNote: "Structured Concurrency",
            stem: "Three try await api.fetch…() in a row, no async let. Timing?",
            options: [
                "Sequential. Total time is roughly the sum",
                "Concurrent, because async functions always overlap",
                "The compiler rewrites them into a task group",
                "They occupy three threads for the whole time",
            ],
            explanation: "Concurrency is opt-in. await means this task waits. Overlap needs async let or a task group (or unstructured Task, which you should not use just to go parallel)."
        ),
    ]

    private static let medium: [DrillQuestion] = [
        DrillQuestion(
            id: "sw.med.async-let-start",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Structured Concurrency",
            stem: "When does fetchProfile start?",
            snippet: """
            async let profile = api.fetchProfile()
            async let feed = api.fetchFeed()
            return try await Dashboard(profile: profile, feed: feed)
            """,
            options: [
                "At the async let declaration, not at the await",
                "Only when profile is first awaited",
                "After fetchFeed returns",
                "On the next main run-loop turn",
            ],
            explanation: "Children start immediately. The await on Dashboard(...) is where this task joins them. Sequential await fetchProfile(); await fetchFeed() would be the slow version of the same code."
        ),
        DrillQuestion(
            id: "sw.med.reentrancy",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Actors",
            stem: "This is an actor method. Two callers load the same uncached URL. What can happen?",
            snippet: """
            func load(_ url: URL) async throws -> Data {
                if let hit = cache[url] { return hit }
                let data = try await download(url)
                cache[url] = data
                return data
            }
            """,
            options: [
                "Both pass the cache check, both download — await let the second job in",
                "Impossible. The actor is locked until load returns",
                "The second caller deadlocks",
                "Isolation is dropped and you get a data race on cache",
            ],
            explanation: "No data race (cache is still actor-isolated). Duplicate work / broken invariant, yes. Re-check after await, or cache an in-flight Task. Isolation ≠ “my local variables still describe the world.”"
        ),
        DrillQuestion(
            id: "sw.med.task-inherits",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Tasks, Cancellation and Priority",
            stem: "What does this print (assuming the closure body is not itself hopping)?",
            snippet: """
            @MainActor
            func tap() {
                Task { print(Thread.isMainThread) }
            }
            """,
            options: [
                "true — Task { } inherits the enclosing isolation",
                "false — Task always lands on the concurrent pool",
                "It does not compile",
                "true only if you write Task.detached",
            ],
            explanation: "Unstructured Task { } inherits actor isolation, priority, and task-locals. That is why wrapping UI work in Task { } does not get you off main. Task.detached inherits nothing — and is almost never what you want."
        ),
        DrillQuestion(
            id: "sw.med.continuation-zero",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Bridging Legacy Code",
            stem: "A withCheckedThrowingContinuation callback returns on the error path without resume. The task:",
            options: [
                "Hangs forever",
                "Throws CancellationError",
                "Crashes immediately with “SWIFT TASK CONTINUATION MISUSE”",
                "Resumes with nil",
            ],
            explanation: "Resume exactly once. Zero times → hang (checked reports when the continuation is released without resume; if you leak it, there is no log). Twice → trap in debug. The guard let x else { return } without resume is the production hang."
        ),
        DrillQuestion(
            id: "sw.med.viewmodel-sendable",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Sendable and Data-Race Safety",
            stem: "@MainActor final class ViewModel — do you need @unchecked Sendable?",
            options: [
                "No. Isolation is the protection; it is already Sendable",
                "Yes. Every class needs @unchecked Sendable",
                "Yes, but only if it has var properties",
                "Classes can never be Sendable",
            ],
            explanation: "People add @unchecked Sendable to view models out of fear. If the type is main-actor-isolated, crossing it into another domain is hopping to that domain, not sharing unsynchronized memory. Unchecked is for when you have a real lock and the compiler cannot see it."
        ),
        DrillQuestion(
            id: "sw.med.task-detached-context",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Tasks, Cancellation and Priority",
            stem: "Task.detached { … } inherits:",
            options: [
                "Nothing — no actor isolation, no task-locals, no live cancellation link",
                "Isolation, but not priority",
                "The same context Task { } inherits",
                "@MainActor automatically in Xcode 26",
            ],
            explanation: "Detached is unstructured and context-free. Cancellation is a snapshot at creation, not a parent link. If the function you call inside is @MainActor, that call still runs on main — isolation is on the declaration."
        ),
        DrillQuestion(
            id: "sw.med.task-to-silence",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Decision Procedure",
            stem: "You wrap a call in Task { } only to make a Swift 6 isolation error go away. What did you likely do?",
            options: [
                "Convert a compile-time isolation error into a runtime race",
                "The supported way to hop off @MainActor",
                "Make the work structured",
                "The same thing as await",
            ],
            explanation: "Task { } is an entry point from sync to async. As an error silencer it picks a new isolation story the compiler is no longer checking the way your original call site was. Name the domain; don't hide the hop."
        ),
        DrillQuestion(
            id: "sw.med.cancellation-unstructured",
            track: .modern,
            difficulty: .medium,
            sourceNote: "Tasks, Cancellation and Priority",
            stem: "You Task { await work() } in a view, then the parent task is cancelled later. That unstructured Task:",
            options: [
                "Is not cancelled just because its creator was — it is not in the structured tree",
                "Always cancels, because it inherited cancellation at creation",
                "Becomes a child of the nearest task group",
                "Inherits cancellation live for its whole life",
            ],
            explanation: "Inheritance is a snapshot at creation. Structured children (async let, task group) are cancelled with the parent. Unstructured work you must store and cancel() yourself."
        ),
    ]

    private static let hard: [DrillQuestion] = [
        DrillQuestion(
            id: "sw.hard.nonsending",
            track: .modern,
            difficulty: .hard,
            sourceNote: "Swift 6.2 and Modern Defaults",
            stem: "Swift 6.2, Approachable Concurrency on. Where does parse run?",
            snippet: """
            nonisolated func parse(_ d: Data) async -> Model { … }

            @MainActor func load() async {
                let m = await parse(data)
            }
            """,
            options: [
                "On the caller's executor (main). async alone does not hop",
                "On the concurrent pool, then back — that is what async means",
                "It deadlocks",
                "It does not compile without @Sendable on Data",
            ],
            explanation: "6.0 hopped nonisolated async to the pool. 6.2 nonisolated(nonsending) stays put. That is why the same helper now “runs on main” and why CPU work needs @concurrent."
        ),
        DrillQuestion(
            id: "sw.hard.concurrent-marker",
            track: .modern,
            difficulty: .hard,
            sourceNote: "Swift 6.2 and Modern Defaults",
            stem: "Under 6.2 defaults, you have CPU-bound thumbnail work that must leave the caller's actor. You:",
            options: [
                "Mark it @concurrent nonisolated (parameters and return Sendable)",
                "Add async — that hops by itself",
                "Wrap URLSession in @concurrent instead; I/O is the same problem",
                "Use Task { } from @MainActor to force a pool thread",
            ],
            explanation: "@concurrent is the explicit opt-out. async is not “go away.” Task { } from main stays on main. @concurrent around URLSession adds hops and occupies nothing useful — the session already suspends."
        ),
        DrillQuestion(
            id: "sw.hard.detached-still-main",
            track: .modern,
            difficulty: .hard,
            sourceNote: "Swift 6.2 and Modern Defaults",
            stem: "New Xcode 26 app (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor). Unannotated func f() async. You call Task.detached { await f() }. Where does f run?",
            options: [
                "Main. Detached inherits no context; f is still @MainActor from the module default",
                "The pool, because detached strips isolation off f",
                "Nonisolated, because detached overrides the build setting",
                "It does not compile",
            ],
            explanation: "Isolation is on the declaration. Task.detached does not rewrite f. This is row 4 of the four-way table: detached + MainActor default still prints main."
        ),
        DrillQuestion(
            id: "sw.hard.two-switches",
            track: .modern,
            difficulty: .hard,
            sourceNote: "Swift 6.2 and Modern Defaults",
            stem: "You set Default Isolation to nonisolated. Approachable Concurrency stays on. Unannotated func f() async is called from @MainActor. Where does f run?",
            options: [
                "Still on main — the caller's executor via nonisolated(nonsending)",
                "The pool — Default Isolation is what used to mean “hop”",
                "It becomes @concurrent",
                "On a new implicit actor",
            ],
            explanation: "Two switches. Default Isolation answers “what is a bare func?” Approachable Concurrency answers “does nonisolated async hop?” Turning only the first one off does not restore 6.0 pool hops."
        ),
        DrillQuestion(
            id: "sw.hard.same-source-two-targets",
            track: .modern,
            difficulty: .hard,
            sourceNote: "Swift 6.2 and Modern Defaults",
            stem: "A file copies from the app target (default isolation MainActor) into an SPM package (typical default: nonisolated). Bare func helper():",
            options: [
                "Changes isolation. App: @MainActor. Package: nonisolated. That is why the package “suddenly” has concurrency errors",
                "Keeps @MainActor because it is in the source",
                "Becomes @concurrent in the package",
                "Isolation is a runtime property of the process, so both targets match",
            ],
            explanation: "Inference plus the module default. The same text is not the same declaration in two targets. Option-click the symbol; do not guess from the call site."
        ),
        DrillQuestion(
            id: "sw.hard.dont-concurrent-io",
            track: .modern,
            difficulty: .hard,
            sourceNote: "Swift 6.2 and Modern Defaults",
            stem: "Why is @concurrent the wrong hammer for await urlSession.data(from:)?",
            options: [
                "URLSession already suspends without occupying a thread; @concurrent only adds hops",
                "URLSession is @MainActor and cannot leave",
                "@concurrent cancels the request on actor reentrancy",
                "The response cannot be Sendable",
            ],
            explanation: "CPU-bound work occupies the caller's executor until it returns. I/O-bound async work should suspend. @concurrent is for thumbnails, decode, hash — not for “I saw await and panicked about main.”"
        ),
    ]
}
