# Lab Setup — the scratch project

> Roadmap: [[00 - Roadmap]] · Drills: [[Drills - How They Work]]
> **Do this before module 03.** Every drill assumes it exists.

The single most valuable thing in this curriculum is a project where the compiler is
configured to shout at you. Twenty minutes now, and every subsequent module has somewhere to run.

---

## 1. Why not a Playground

Playgrounds are the wrong tool here and will actively mislead you:

- Their top-level code runs on the main actor, so thread-hopping experiments silently do
  nothing.
- Strict concurrency settings aren't reliably applied.
- Async top-level code sometimes finishes before your tasks do, so output vanishes.

Use a **command-line tool** for isolation/actor drills (clean, no UI, fast, and *not*
main-actor by default), and a **SwiftUI app** for the ones about `@MainActor`, `.task`, and
cancellation.

---

## 2. Create the two targets

```bash
mkdir -p ~/Developer/ConcurrencyLab && cd ~/Developer/ConcurrencyLab
swift package init --type executable --name ConcurrencyLab
```

Then edit `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConcurrencyLab",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ConcurrencyLab",
            swiftSettings: [
                // The whole point of the lab:
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
```

> **Note on the language mode.** `.swiftLanguageMode(.v6)` makes data-race violations
> **errors**. That's what you want for drills. If you'd rather start with warnings while you
> find your feet, drop that line and keep only the strict-concurrency flag — but promise
> yourself you'll flip it on by module 06, because warnings are easy to scroll past.

For the UI drills, also make a plain SwiftUI app in Xcode (`ConcurrencyLabApp`). In its Build
Settings set:

| Setting                     | Value         | Why                                                   |
| :-------------------------- | :------------ | :---------------------------------------------------- |
| Swift Language Mode         | **6**         | Errors, not warnings                                  |
| Strict Concurrency Checking | **Complete**  | Check everything, not just what's annotated           |
| Default Actor Isolation     | **MainActor** | The Xcode 26 default — learn the world you'll ship in |
| Approachable Concurrency    | **Yes**       | Enables `nonisolated(nonsending)` behaviour           |

Run once with *Default Actor Isolation* set to `nonisolated` too, so you've seen both. The
contrast is the fastest way to internalise [[11 - Swift 6.2 and Modern Defaults]].

---

## 3. Turn on the runtime detectors

Compile-time checking catches most things. These catch the rest.

**Thread Sanitizer** — Product → Scheme → Edit Scheme → Run → Diagnostics → ✅ Thread
Sanitizer. Catches real data races at runtime. Slows execution ~5–15×; that's fine for drills.

**Main Thread Checker** — on by default. Catches UIKit/AppKit calls made off the main thread.

**`-warn-concurrency` runtime warnings** — in Swift 5 mode, add `-Xfrontend
-warn-concurrency` to Other Swift Flags to surface main-actor violations as runtime purple
warnings rather than silent bugs. Not needed once you're in Swift 6 mode.

> **Do not skip Thread Sanitizer.** The compiler proves the absence of races in code it can
> see. TSan finds the ones you smuggled past it with `@unchecked Sendable`, `nonisolated(unsafe)`,
> or a C library. Drill 06 exists specifically to show you one.

---

## 4. Utilities to paste into the lab

Put this in `Sources/ConcurrencyLab/Support.swift`. Every drill uses it.

```swift
import Foundation

/// Where am I *actually* running? Use this constantly while learning.
/// `nonisolated` is load-bearing: under Default Isolation = MainActor an unannotated
/// helper would itself be `@MainActor` and every call would print MAIN.
nonisolated func here(_ label: String, function: String = #function) {
    let thread = Thread.isMainThread ? "MAIN" : "bg  "
    print("[\(thread)] \(label) — \(function)")
}

/// Measure a block of async work.
nonisolated func timed<T>(_ label: String, _ work: () async throws -> T) async rethrows -> T {
    let clock = ContinuousClock()
    var result: T!
    let elapsed = try await clock.measure { result = try await work() }
    print("⏱  \(label): \(elapsed)")
    return result
}

/// Simulated network call — never blocks a pool thread.
nonisolated func fakeFetch(_ name: String, ms: Int = 300) async throws -> String {
    try await Task.sleep(for: .milliseconds(ms))
    return "payload:\(name)"
}

/// Deliberately CPU-bound work, for the drills that need real contention.
/// Note: this does NOT suspend, so it occupies its thread for the duration.
nonisolated func burnCPU(iterations: Int = 5_000_000) -> Double {
    var acc = 0.0
    for i in 1...iterations { acc += (Double(i)).squareRoot() }
    return acc
}
```

> `Thread.isMainThread` is a blunt instrument and warns under strict concurrency — which is
> itself instructive, since thread identity is meaningless in this model. It is still the
> quickest way to *see* a hop while learning. Once you reach module 11 you'll replace it with
> proper isolation reasoning and delete `here()` entirely.

---

## 5. Seeing tasks in Instruments

From module 08 onward, run the **Swift Concurrency** instrument template (Xcode → Product →
Profile → Swift Concurrency). It gives you three views worth knowing:

- **Task Forest** — the parent/child tree. This is how you *see* structured concurrency, and
  it makes `async let` vs `Task { }` visually obvious.
- **Task Summary** — how long tasks spent running vs suspended. Lots of suspension is normal
  and healthy; lots of *waiting to start* means contention.
- **Alive Tasks** — a line that climbs and never falls is a task leak.

Add signposts to make your own work legible:

```swift
import OSLog
let signposter = OSSignposter(subsystem: "lab", category: "drills")

func instrumented() async {
    let state = signposter.beginInterval("fetch")
    defer { signposter.endInterval("fetch", state) }
    _ = try? await fakeFetch("a")
}
```

This is also the answer to the performance half of the "level up" plan — the same skill,
applied to concurrency.

---

## 6. Checklist

- [x] SPM executable target builds in Swift 6 language mode
- [x] SwiftUI app target with the four Build Settings above
- [x] Thread Sanitizer enabled on both schemes
- [x] `Support.swift` pasted in, `here("hello")` prints
- [x] You ran the same function with *Default Actor Isolation* set both ways and saw the
      output differ

When the last box is ticked, start [[03 - Isolation - The Core Concept]].
