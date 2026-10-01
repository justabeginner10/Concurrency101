# The Decision Procedure

> **This is the note you open while coding, not while studying.**
> Roadmap: [[00 - Roadmap]] · Terms: [[Glossary]] · Progress: [[Progress]]

You are mid-implementation. Something won't compile, or it compiles but you don't know what
it's doing. Don't reach for a tutorial. Work the procedure.

---

## Part 1 — The three questions

Ask them **in this order**. Most confusion dissolves at question 1.

### Q1. Where does this code run?

Every declaration in Swift is exactly one of three things:

| Isolation | Means | Written as |
| :--- | :--- | :--- |
| **Main-actor-isolated** | Runs on the main thread, serialised with all other main-actor code | `@MainActor` |
| **Actor-isolated** | Runs on that actor's serial executor, one call at a time | a method inside `actor Foo` |
| **Nonisolated** | Protected by nothing. May run anywhere, concurrently with anything | `nonisolated`, or a plain `func` in a nonisolated type |

**If you cannot name which one this function is, stop.** That is the entire source of your
confusion, and nothing downstream will make sense until you answer it. Don't guess from the
call site — isolation is a property of the *declaration*, decided at compile time.

Two things make this genuinely hard to see, and both are invisible in the source:

1. **Inference.** An unannotated declaration inherits isolation from its enclosing type, its
   protocol conformances, or its superclass.
2. **The module default.** Xcode 26 sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a
   bare `func` is implicitly `@MainActor` — in *that* module. The same code in a package
   without the setting is nonisolated. See [[11 - Swift 6.2 and Modern Defaults]].

> **The habit that fixes this permanently:** while you are learning, write the isolation
> explicitly on every declaration, even when inference would have got it right. You are
> trading a little noise for the ability to answer Q1 by *reading* instead of deducing.

**How to check when you genuinely can't tell:** Option-click the symbol in Xcode. The
quick-help panel shows the inferred isolation. This is faster and more reliable than reasoning
about it, and there's no shame in it.

### Q2. What mutable state am I touching, and who owns it?

Mutable state needs exactly **one** owner. Find the state, name the owner:

| State | Owner should be |
| :--- | :--- |
| Anything a SwiftUI view reads, view-model properties, UIKit views | `@MainActor` |
| A cache, a session store, a connection pool, a counter | an `actor` |
| A constant (`let` of a `Sendable` type) | nobody — it needs no protection |
| A value type you hand off and never touch again | nobody — it gets copied |
| Something genuinely needing a lock (perf-critical, no `async`) | `Mutex` from `Synchronization` |

If two different isolation domains can touch the same mutable state, you have a bug — whether
or not the compiler has noticed yet.

> **The heuristic that removes most problems:** make it a `struct` of `let`s. A `Sendable`
> value type crosses every boundary for free because it's copied, and there is no shared
> state to race on. Most "how do I make this Sendable" questions are really "why is this a
> class?"

### Q3. Am I awaiting, or spawning?

These are not interchangeable and choosing wrong is the #1 cause of bugs you can't reproduce:

| | `await foo()` | `Task { await foo() }` |
| :--- | :--- | :--- |
| Ordering | Preserved — the next line runs after | None — the next line runs immediately |
| Errors | Propagate to your caller | **Swallowed unless you handle them inside** |
| Cancellation | Inherited from the enclosing task | Inherited from context, but it's a *new* task you must store to cancel |
| Return value | You get it | You don't |
| Isolation | Stays in the current domain | Inherits the enclosing *lexical* context |
| Use it when | You need the result before continuing | You're crossing from sync code into async (a button tap, `viewDidLoad`) |

> **🚩 The red flag:** if you are adding `Task { }` to make an error go away, stop. You almost
> certainly answered Q1 wrong, and you have just converted a compile-time error into a runtime
> race. `Task { }` is for entering async code from a synchronous entry point — it is not a
> repair tool.

---

## Part 2 — Symptom → cause → fix

Find your error. The **cause** column is the part worth reading.

### "Main actor-isolated property 'x' can not be referenced from a nonisolated context"

**Cause:** you're in a nonisolated function trying to touch main-actor state.
**Fix, in order of preference:**

1. Should the whole function be on the main actor? Mark it `@MainActor`. *(Usually yes for
   UI-adjacent code — don't be shy about this.)*
2. Only the touch needs to be on main? Make the function `async` and `await` the access.
3. Genuinely can't be async (you're in a delegate callback that must be sync)? Then
   `MainActor.assumeIsolated { }` — but **only** when you can prove you're already on the
   main thread. It traps if you're wrong. See [[05 - MainActor and Global Actors]].

### "Sending 'x' risks causing data races" / "Type 'X' does not conform to 'Sendable'"

**Cause:** a value is crossing an isolation boundary and the compiler can't prove that's safe.
**Fix, in order of preference:**

1. **Make it a value type.** `struct` of `Sendable` members gets `Sendable` for free.
2. **Don't cross the boundary.** Extract the `Sendable` piece you need *before* the hop and
   send that instead of the whole object.
3. **Make it an actor.** If it's a mutable reference type shared by design, that's what actors
   are for.
4. `final class` with only `let` properties of `Sendable` type → add `: Sendable`.
5. `@unchecked Sendable` — only with a lock/queue inside and a comment explaining the
   invariant you're asserting. You are telling the compiler "trust me"; be worth trusting.
6. `nonisolated(unsafe)` — last resort, single declarations, same rule.

Full decision tree in [[06 - Sendable and Data-Race Safety]].

### "Actor-isolated property 'x' can not be mutated from a Sendable closure"

**Cause:** you captured actor state inside an escaping closure that runs later, elsewhere.
**Fix:** don't capture the state; capture the *actor* and hop to it (`await actor.update()`).

### "Expression is 'async' but is not marked with 'await'"

**Cause:** just a missing keyword — but read it as information. The compiler is telling you
**this is a suspension point**: things can change here. Add the `await`, then ask whether any
assumption you made above this line survives it. See §4 of [[02 - Async Await Deep Dive]].

### "Call to main actor-isolated initializer in a synchronous nonisolated context"

**Cause:** usually a `@MainActor` type being constructed in a `nonisolated` default value,
a global, or a `static let`.
**Fix:** make the property lazy, mark the containing context `@MainActor`, or make the type
nonisolated if it doesn't actually need main.

### It compiles, but my UI doesn't update / "Publishing changes from background threads"

**Cause:** your state mutation is happening off the main actor. Under Swift 6 this is usually
a compile error; if you're still in Swift 5 mode it's a runtime warning or silent bug.
**Fix:** mark the observable object or view model `@MainActor`. This is the single most common
correct answer in app code, and the whole reason Xcode 26 made it the default.

### My `async` function isn't running in the background

**Cause:** `async` does **not** mean "background". If the caller is on the main actor and your
function is main-actor-isolated (possibly by module default), it runs on main.
**Fix:** if it's genuinely CPU-heavy work that must leave the caller, mark it
`@concurrent nonisolated`. See [[11 - Swift 6.2 and Modern Defaults]].

### It deadlocks / hangs forever

**Cause:** you blocked a cooperative pool thread. Search your code for `DispatchSemaphore`,
`.wait()`, `DispatchQueue.sync`, `Thread.sleep`, or synchronous I/O inside async code.
**Fix:** there is no workaround. Restructure so the caller is `async`. See §3 of
[[01 - Mental Model]].

### State changed unexpectedly between two lines of my actor method

**Cause:** **actor reentrancy.** There's an `await` between them, and the actor ran other work
during the suspension. Actors prevent data races, not stale invariants.
**Fix:** re-check your guard conditions *after* every `await`, or hold an in-flight task
handle so the second caller joins the first instead of duplicating work. See §4 of
[[04 - Actors]].

---

## Part 3 — The bailout

Stuck for more than ten minutes on one error? Run this, in order:

1. **Option-click the symbol.** Read the actual inferred isolation instead of reasoning about
   it. (Half the time you'll find the answer here and the other half you'll find out your
   mental model of the file was wrong.)
2. **Read the full error, including the notes.** Swift 6's diagnostics name the exact value
   and the exact boundary it crosses. The second line is usually more useful than the first.
3. **Write the isolation explicitly** on the function and its callers. Errors move to where
   the real problem is.
4. **Ask "what would break if two threads ran this at once?"** If the honest answer is
   "nothing, there's no shared mutable state" — you probably have a `Sendable` annotation
   problem, not a design problem. If the answer is "a lot" — you have a design problem, and
   the compiler just saved you.
5. **Try deleting the concurrency instead of adding more.** Does this need to be async at all?
   A great deal of concurrency in app code is cargo-culted. The best fix is often to make the
   function synchronous and main-actor-isolated and move on with your life.

---

## Part 4 — Default answers for app code

When you have no strong reason to do otherwise, these are right far more often than not.
Have a reason before departing from them.

- **View models, observable objects, anything UI touches** → `@MainActor`.
- **Networking and decoding** → `nonisolated async`, returning `Sendable` value types.
- **Shared mutable caches/stores** → `actor`.
- **Model types crossing boundaries** → `struct`, all `Sendable`.
- **Entering async from a UI callback** → `.task { }` in SwiftUI (auto-cancels), `Task { }`
  in UIKit (store the handle if it needs cancelling).
- **CPU-heavy work** → `@concurrent nonisolated func`.
- **`Task.detached`** → almost never. If you're reaching for it, re-read Q3.

> Being on the main actor is not a performance problem. Doing *heavy work* on the main actor
> is. Those are different statements, and conflating them causes more bad architecture than
> almost anything else in iOS.
