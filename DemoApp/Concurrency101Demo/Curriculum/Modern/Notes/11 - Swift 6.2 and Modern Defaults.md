# Module 11 — Swift 6.2 and Modern Defaults

> Roadmap: [[00 - Roadmap]] · Terms: [[Glossary]] · Prev: [[10 - AsyncSequence and AsyncStream]] ·
> Next: [[12 - Migrating to Swift 6]]
> **Goal:** understand why the same code behaves differently in two of your targets.
> Drill: [[Drill 11 - Same Code, Four Behaviours]]

> ⚠️ **Version-sensitive.** This module describes Swift 6.2 / Xcode 26 behaviour. Toolchains
> move; when something here contradicts your compiler, believe the compiler and update the
> note. Check yours with `swift --version`.

---

## 1. The problem 6.2 was solving

Swift 6.0 shipped strict data-race safety and everyone immediately hit the same wall: a normal
app, where practically everything is UI-adjacent, generated hundreds of errors about crossing
boundaries it had no intention of crossing. The language was making you *prove* things about
concurrency you never asked for.

Swift 6.2's answer, roughly: **stop assuming code wants to be concurrent.** Make single-domain
(usually main-actor) code the frictionless default, and require an explicit marker when you
actually want to leave.

That is why your code may now run on the main thread where you expected a background one. It's
not a bug; it's the new default, and once you know it, most of the confusion in this area
evaporates.

---

## 2. `nonisolated(nonsending)` — async functions stay put

**Before (Swift 6.0):** a `nonisolated async` function hopped to the global concurrent pool.

**Now (with approachable concurrency):** it runs on **the caller's** executor.

```swift
nonisolated func parse(_ d: Data) async -> Model { ... }

@MainActor func load() async {
    let m = await parse(data)     // 6.0: hops to pool. 6.2: stays on main.
}
```

Why this is better: the old behaviour meant every `nonisolated async` helper forced a hop out
and a hop back, and forced its arguments and return to be `Sendable` — for a function that did
nothing concurrent. The new behaviour makes the common case free and the concurrent case
explicit.

Spelled explicitly as `nonisolated(nonsending) func`; it's the default under the
*Approachable Concurrency* build setting.

---

## 3. `@concurrent` — the explicit opt-out

```swift
@concurrent nonisolated func makeThumbnail(_ data: Data) async -> Image {
    // genuinely CPU-heavy — must not occupy the caller's actor
}
```

Under 6.2 defaults this is **the** way to guarantee an async function leaves the caller's
domain. Its parameters and return must be `Sendable`, because it really does cross a boundary.

> **The new rule of thumb:** `async` alone no longer implies "goes somewhere else." If you want
> off the caller's executor, say `@concurrent`. If you don't, you get to keep your
> non-`Sendable` arguments and skip two hops.

Use it for: image processing, encryption, large JSON decode, compression, anything CPU-bound.
Don't use it for: I/O. `URLSession` already suspends without occupying a thread — wrapping it
in `@concurrent` adds hops and buys nothing.

---

## 4. Default actor isolation

```
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor      // Xcode 26 default for NEW app projects
```

Every unannotated declaration in the module becomes `@MainActor`. In an app target this is
usually right: most app code is UI-adjacent, and this removes a large class of spurious errors.

But note the asymmetry that causes real confusion:

| Target | Typical setting | So a bare `func` is… |
| :--- | :--- | :--- |
| New Xcode 26 app | `MainActor` | `@MainActor` |
| Existing migrated app | `nonisolated` | nonisolated |
| SPM package (unless configured) | `nonisolated` | nonisolated |

**The same source file means different things in your app target and your package.** When you
move code into a package during modularisation and it suddenly produces twenty concurrency
errors, this is why.

To set it for a package:

```swift
.target(name: "Feature", swiftSettings: [.defaultIsolation(MainActor.self)])
```

---

## 5. The four-way behaviour table

Called from a `@MainActor` context. This is the table worth committing to memory:

| Declaration | Xcode 26 defaults | `Default Isolation = nonisolated` |
| :--- | :--- | :--- |
| `func f() async` | 🟢 main | ⚪️ background |
| `nonisolated func f() async` | 🟢 main (caller's executor) | ⚪️ background |
| `@concurrent nonisolated func f() async` | ⚪️ background | ⚪️ background |
| `func f() async` via `Task.detached` | 🟢 **main** | ⚪️ background |

That last row is the one that proves the principle from
[[03 - Isolation - The Core Concept]]: `Task.detached` inherits nothing, and the function
*still* runs on main — because `@MainActor` was baked into the declaration by the module
default, not passed down by the caller. **Isolation is static.**

---

## 6. Other 6.x features worth knowing

### Isolated conformances

```swift
@MainActor final class ViewModel: @MainActor Identifiable { }
```
Lets a `@MainActor` type conform to a nonisolated protocol when the conformance itself is only
used from the main actor. Removes a family of "cannot satisfy nonisolated requirement" errors
that previously forced `nonisolated` members or `@unchecked Sendable`.

### `Task.immediate`

```swift
Task.immediate {
    isLoading = true              // runs NOW, synchronously
    let data = await fetch()      // suspends here
}
```
Starts the body synchronously on the current context until the first suspension, instead of
enqueueing it for a later turn. Fixes the flicker where `isLoading = true` inside a plain
`Task { }` landed one run-loop turn late.

### Task names

```swift
Task(name: "refresh-feed") { await refresh() }
```
Shows up in Instruments' Task Forest and in the debugger. Cheap, and it makes concurrency
profiling legible — do it for any task that isn't trivially identifiable.

### `Mutex` (Synchronization)

```swift
import Synchronization
let counter = Mutex(0)
counter.withLock { $0 += 1 }
```
For synchronous critical sections with no `await` inside. Covered in §7 of [[04 - Actors]].

### `sending` and region isolation

Swift 6.0, but it's what makes 6.2 pleasant. See §5 of
[[06 - Sendable and Data-Race Safety]].

---

## 7. What to set, by target type

| Target | Language Mode | Strict Concurrency | Default Isolation | Approachable |
| :--- | :--- | :--- | :--- | :--- |
| New app | 6 | Complete | MainActor | Yes |
| Migrating app | 5 → 6 | Minimal → Targeted → Complete | nonisolated at first | Yes |
| UI package | 6 | Complete | MainActor | Yes |
| Networking / model package | 6 | Complete | **nonisolated** | Yes |
| The lab | 6 | Complete | try both | Yes |

Model and networking packages should stay `nonisolated` — they're the code you *want* usable
from any domain. Making them main-isolated by default is how you accidentally serialise your
whole app through the main thread.

---

## 8. Pitfalls

**8.1 — Expecting `async` to mean background.** It doesn't, and under 6.2 it usually isn't.

**8.2 — Not knowing the setting per module.** Check every target. They differ, and the
difference is invisible in the source.

**8.3 — `@concurrent` on I/O.** Adds hops, saves nothing.

**8.4 — Assuming a package behaves like your app target.** §4.

**8.5 — Turning `MainActor` default on for a model/networking layer.** §7.

**8.6 — Reading pre-6.2 blog posts as current.** A great deal of widely-cited Swift concurrency
writing predates these defaults and will actively mislead you. Check the date; prefer the
migration guide and the evolution proposals.

---

## 9. Drill gate

→ **[[Drill 11 - Same Code, Four Behaviours]]**

Run one file through all four rows of §5 and verify every cell yourself. Predict each, then
measure. This drill is short and it permanently fixes the "why is this on main?" question.
