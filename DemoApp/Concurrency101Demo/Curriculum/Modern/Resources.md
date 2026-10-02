# Resources

> Terms: [[Glossary]] · Curated, not exhaustive. Ordered by how useful they actually are.

> ⚠️ **Check the date on everything.** Swift concurrency changed substantially in 6.0 (strict
> checking, region isolation) and again in 6.2 (approachable concurrency, default isolation).
> A great deal of widely-cited writing predates these and will actively mislead you. If a post
> says "`nonisolated async` runs on the global pool" with no caveat, it's pre-6.2.

---

## 1. Primary sources — read these

| Source | Why |
| :--- | :--- |
| [Swift Migration Guide](https://www.swift.org/migration/documentation/migrationguide/) | The single best document on Swift 6. Short, practical, written by the people who built it. **Read it end to end during Phase D.** |
| [TSPL — Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) | The language reference. Dry, correct, current. |
| [Swift Evolution proposals](https://github.com/swiftlang/swift-evolution/tree/main/proposals) | The *why*. See §2. |
| [Apple: Updating an app to use strict concurrency](https://developer.apple.com/documentation/swift/updating-an-app-to-use-swift-concurrency) | Apple's migration walkthrough |

## 2. Evolution proposals worth reading in the original

Once Phase B is done these become readable, and each one's **Motivation** section explains a
design decision that otherwise looks arbitrary.

| Proposal | Topic | Read after |
| :--- | :--- | :--- |
| [SE-0296](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md) | async/await | module 02 |
| [SE-0306](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md) | Actors — **the reentrancy rationale is here** | module 04 |
| [SE-0316](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) | Global actors | module 05 |
| [SE-0302](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md) | `Sendable` | module 06 |
| [SE-0304](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md) | Structured concurrency | module 08 |
| [SE-0414](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md) | Region-based isolation | module 06 |
| [SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) | `sending` | module 06 |
| [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) | `nonisolated(nonsending)`, `@concurrent` | module 11 |
| [SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md) | Default actor isolation | module 11 |

> Reading proposals is a senior-engineer habit worth building generally. They're the only place
> the trade-offs are written down, including the ones that were rejected.

## 3. WWDC — in viewing order

| Session | Year | Note |
| :--- | :--- | :--- |
| Meet async/await | 21 | Foundations, still accurate |
| Protect mutable state with actors | 21 | **The reentrancy explanation is the best one filmed** |
| Explore structured concurrency | 21 | Task trees, cancellation |
| Eliminate data races using Swift Concurrency | 22 | The isolation mental model |
| Visualize and optimize Swift concurrency | 22 | Instruments — Task Forest, task leaks |
| Beyond the basics of structured concurrency | 23 | Task-locals, cancellation depth |
| Migrate your app to Swift 6 | 24 | Practical migration |
| Embracing Swift concurrency | 25 | The 6.2 defaults and the reasoning |

## 4. Tools

| Tool | Use |
| :--- | :--- |
| [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) | `debounce`, `merge`, `zip`, `chunked` — the missing operators |
| [swift-clocks](https://github.com/pointfreeco/swift-clocks) | `TestClock` — deterministic time in tests |
| [Swift Testing](https://developer.apple.com/documentation/testing) | `confirmation`, `.timeLimit`, `.serialized` |
| Thread Sanitizer | Built into Xcode. The only thing that catches what the compiler can't |
| Instruments → Swift Concurrency | Task Forest, alive tasks, task leaks |

## 5. Writing worth reading

- **Matt Massicotte** ([massicotte.org](https://www.massicotte.org)) — the most reliable
  current writing on Swift concurrency, particularly on isolation and migration. If you read
  one blog, this one. His "Concurrency Step-by-Step" series pairs well with Phase B.
- **Donny Wals** — practical, app-focused, keeps posts updated.
- **Point-Free** — deeper, more opinionated, strong on testing and dependency injection.
- **Swift Forums → Concurrency** — where the actual designers answer questions. Search here
  before Stack Overflow; the signal-to-noise is dramatically better and the answers are current.

## 6. Reference cards

- [[00 - Decision Procedure]] — the one you'll open most
- [[Glossary]] — precise definitions; most concurrency confusion is vocabulary confusion
- §5 of [[11 - Swift 6.2 and Modern Defaults]] — the four-way behaviour table

## 7. Deliberately not here

Most "Swift concurrency tutorial" content. It's abundant, mostly pre-6.2, and mostly teaches
syntax you already know. Your gap was never syntax — it was isolation, and that's what the
sources above actually cover.
