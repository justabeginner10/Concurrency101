# Glossary

> Roadmap: [[00 - Roadmap]] · While coding: [[00 - Decision Procedure]] · Progress: [[Progress]]
> Precision matters here — **most concurrency confusion is vocabulary confusion.**

---

### `@concurrent`
Swift 6.2 attribute on a `nonisolated async` function, meaning "run on the global concurrent
pool rather than the caller's executor." Under Xcode 26 defaults it is the *only* reliable way
to make an async function leave the caller's domain. For CPU-bound work; pointless on I/O.
[[11 - Swift 6.2 and Modern Defaults]]

### `assumeIsolated`
`MainActor.assumeIsolated { }` asserts you are *already* on the main actor and runs a closure
synchronously with no hop. **Traps at runtime if you're wrong.** For legacy callbacks
documented to fire on main. [[05 - MainActor and Global Actors]]

### Asynchronous function
A function marked `async`. Allowed to **suspend** — give up its thread part-way and resume
later. Callable only from an async context. Note: `async` says nothing about *where* it runs.
[[01 - Mental Model]]

### `AsyncSequence`
`Sequence` whose iteration can suspend, consumed with `for await`. **Unicast** in the
`AsyncStream` case — two consumers split the values rather than each receiving all.
[[10 - AsyncSequence and AsyncStream]]

### `AsyncStream`
Bridges a callback/delegate source into an `AsyncSequence` via a `Continuation` you `yield` to.
Its `onTermination` handler is where you tear down the underlying source — omitting it is the
most common `AsyncStream` bug. [[10 - AsyncSequence and AsyncStream]]

### `await`
The marker that a call *may* suspend. **Not** "wait/block" — it releases the thread. Every
`await` is a place where other work can run and your assumptions can go stale. The compiler
forces you to write it so those points are visible in the source.
[[02 - Async Await Deep Dive]]

### Cancellation
**Cooperative.** `task.cancel()` sets a flag; it interrupts nothing. Code must check
(`Task.checkCancellation()`, `Task.isCancelled`) or call an API that checks for it. Flows down
the structured task tree; unstructured tasks are not in that tree.
[[09 - Tasks, Cancellation and Priority]]

### Concurrency
Multiple tasks *in progress* over the same period, interleaved. Does not require more than one
CPU core. Contrast **parallelism**.

### Continuation
The captured "rest of the function" — where to resume and the state to do it with. Swift
compiles an async function into a state machine whose resumption points are continuations,
stored on the heap rather than a thread stack. Also the explicit bridging API
(`withCheckedContinuation`), which must be resumed **exactly once** — zero resumes hangs
forever, two crashes. [[07 - Bridging Legacy Code]]

### Cooperative thread pool
The fixed-size pool the runtime schedules tasks onto — roughly one thread per core.
"Cooperative" because tasks yield voluntarily (by suspending) rather than being preempted.
**Blocking one of these threads is the cardinal sin** and can deadlock the whole app.
[[01 - Mental Model]]

### Default actor isolation
Build setting `SWIFT_DEFAULT_ACTOR_ISOLATION`. Set to `MainActor` (Xcode 26 default for new
app projects), every unannotated declaration in *that module* is implicitly `@MainActor`.
Packages usually aren't configured this way, so the same source means different things in
different targets. [[11 - Swift 6.2 and Modern Defaults]]

### Executor
Decides *where and when* a task's next chunk of work runs. A **serial executor** runs one job
at a time (every actor has one); the **global concurrent executor** backs the cooperative pool.

### Forward progress
The runtime's guarantee that a started task won't be blocked indefinitely by the runtime
itself. Upheld only if your code never blocks a pool thread.

### Global actor
An actor usable as an annotation anywhere, declared with `@globalActor`. `@MainActor` is the
built-in one. Every declaration marked with a given global actor shares one process-wide
executor. [[05 - MainActor and Global Actors]]

### Hop
Moving execution from one isolation domain to another. Hops happen only at `await`, and they
cost a scheduling round-trip — which is why chatty cross-actor call patterns are slow.

### `isolated` parameter
`func f(on actor: isolated MyActor)` — the function runs *on* that actor, so it can touch its
state directly with no `await` per access. The fix for chatty boundaries: hop once, do
everything. [[03 - Isolation - The Core Concept]]

### Isolation
**The central concept.** A compile-time property of a *declaration* saying which isolation
domain its code and state belong to. Static, not dynamic: it does not propagate from the
calling thread. [[03 - Isolation - The Core Concept]]

### Isolation domain
A region of code and state the compiler guarantees is entered by one thing at a time. Exactly
three kinds: main-actor-isolated, actor-isolated (per *instance*), and nonisolated.

### `Mutex`
From the `Synchronization` module. A lock for **synchronous** critical sections — no `await`
inside, by design. Preferable to an actor when the critical section doesn't suspend, because it
doesn't force `async` onto every caller. [[04 - Actors]]

### `nonisolated`
Belonging to **no** isolation domain — i.e. protected by nothing, may run concurrently with
anything. ⚠️ Does **not** mean "background": under Swift 6.2 defaults a `nonisolated async`
function runs on the *caller's* executor. It's the right and safe choice for code with no
mutable state.

### `nonisolated(nonsending)`
Swift 6.2: an async function runs on the caller's executor instead of hopping to the pool. The
default under *Approachable Concurrency*. [[11 - Swift 6.2 and Modern Defaults]]

### `nonisolated(unsafe)`
Suppresses isolation checking for one declaration. A promise you're synchronising by other
means. Same rules as `@unchecked Sendable`: needs a real mechanism and a comment.

### Parallelism
Multiple tasks *executing at the same instant* on different cores. Requires concurrency;
concurrency does not require it. `await` gives concurrency — parallelism needs *separate tasks*
(`async let`, task groups) that are also `nonisolated`.

### `@preconcurrency`
Marks an import, protocol or declaration as predating concurrency checking, downgrading related
errors to warnings. The right tool for third-party SDKs; not for your own code.
[[12 - Migrating to Swift 6]]

### Reentrancy
While an actor-isolated method is suspended at an `await`, the actor may run **other jobs —
including another call to the same method**. Actors prevent *data races*, not *stale
invariants*. The most common source of subtle bugs. [[04 - Actors]]

### Region-based isolation
Swift 6 analysis proving a non-`Sendable` value is safe to transfer because the sender
provably stops using it. Why many Swift 5.10-era `Sendable` errors no longer appear — if you
hit one on a value you never touch again, check your compiler version before redesigning.
[[06 - Sendable and Data-Race Safety]]

### `Sendable`
Marker protocol asserting a value is safe to use from more than one isolation domain. Mental
shortcut: **copied, or immutable, or internally synchronised.** Value types of `Sendable`
members get it automatically; mutable classes don't; isolated types (`actor`, `@MainActor`) get
it for free. [[06 - Sendable and Data-Race Safety]]

### `@Sendable` closure
A closure safe to run in another domain — so everything it captures must be `Sendable`, and it
**does not inherit isolation**. `Task.detached`, `DispatchQueue.async` and task-group children
take these. (`Task { }` is the exception: it inherits the enclosing isolation.)

### `sending`
Parameter/result modifier meaning "this value is **moving**, not being shared." Lets non-
`Sendable` values be handed off safely. [[06 - Sendable and Data-Race Safety]]

### Structured concurrency
Child tasks whose lifetimes are bounded by a syntactic scope (`async let`, task groups). The
parent can't return until children finish, so errors, cancellation and priority propagate
predictably. The opposite is an **unstructured** task (`Task {}`, `Task.detached`).
[[08 - Structured Concurrency]]

### Suspension point
The precise place an async function may pause — exactly the `await` expressions, plus
`async let` reads and `for await` iterations. Between two suspension points your code runs
**atomically within its isolation domain**, which is a real guarantee you can build on.

### Task
The unit of async work — cheaper than a thread, scheduled by the runtime, **not pinned to a
thread**. Carries priority, cancellation state, task-locals and isolation. Tasks form a tree;
cancelling a parent cancels its (structured) children.

### Task-local value
`@TaskLocal` — the replacement for thread-local storage, which is meaningless here because
tasks migrate between threads. Propagates down the structured tree and into `Task { }`, but not
`Task.detached`. [[09 - Tasks, Cancellation and Priority]]

### Thread explosion
The GCD failure mode where blocked queue items each cause another thread to be spun up,
exhausting memory and thrashing the scheduler. The cooperative pool's fixed size exists to make
this impossible. [[01 - Mental Model]]

### `@unchecked Sendable`
"Trust me, I've synchronised this." Legitimate **only** with a real lock/queue/atomic and a
comment naming it. Without one it is a data race with the alarm switched off.
[[06 - Sendable and Data-Race Safety]]
