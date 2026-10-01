# 🏁 Capstone

> Roadmap: [[00 - Roadmap]] · Drills: [[Drills - How They Work]]
> **Do this when modules 03–13 are done.** It's the difference between having studied this and
> being able to use it.

---

## The brief

Build a small app — **three screens maximum** — that uses every concept in the curriculum
honestly. Not a demo of each feature in isolation; a real thing where each choice is the right
one for the job.

Suggested shape: a **paginated feed with images and search**. It's small enough to finish and
it naturally requires everything.

### Requirements

| # | Requirement | Modules |
| :--- | :--- | :--- |
| 1 | Swift 6 language mode, strict concurrency complete, **zero `@unchecked Sendable`** | 06, 12 |
| 2 | `@MainActor` view models; networking `nonisolated` | 03, 05 |
| 3 | An `actor` image cache that deduplicates in-flight requests | 04 |
| 4 | Parallel fetch with a concurrency limit | 08 |
| 5 | Debounced search that cancels correctly | 09 |
| 6 | One legacy API wrapped with a cancellable continuation | 07 |
| 7 | One delegate or notification source exposed as `AsyncStream`, with cleanup | 10 |
| 8 | CPU-heavy work (image downsampling) off the main actor with `@concurrent` | 11 |
| 9 | Tests: one for reentrancy, one for cancellation, none using `Task.sleep` as sync | 13 |
| 10 | Clean under Thread Sanitizer | all |

---

## The bar

Anyone can produce code that compiles. The capstone is done when you can **explain every
isolation decision in it**:

- Why is this type `@MainActor` and that one an actor?
- Why is this function `nonisolated` rather than isolated?
- Where exactly could reentrancy bite, and what stops it?
- Which values cross boundaries, and why is each one safe to cross?
- Where are the suspension points, and what could change at each?

Walk a colleague through it. If you can't defend a decision, that's the part you don't
understand yet — go back to the module and the Error Log.

---

## Then: write it up

Turn it into a post. Not a tutorial — a **findings** post:

- "Three Swift 6 concurrency bugs that don't crash" (reentrancy, continuation leak, stream leak)
- "What I got wrong about `async`" — using your own Error Log as the source
- "Migrating a module to Swift 6: the numbers" — from [[Drill 12 - Migrate One Module]]

Your Error Log is the raw material, and it's *better* material than most published Swift
concurrency writing, because it's a record of real confusion rather than a rehearsed
explanation. The forcing function of "someone will fact-check this" is also the fastest way to
find the last few soft spots in your understanding.

That's also the "proof of work" half of levelling up: depth you can point at.

---

## After the capstone

- Re-read [[00 - Decision Procedure]]. It should now read as obvious. If any part doesn't, that
  module needs another pass.
- Keep the Error Log. Add to it from real work.
- Read the evolution proposals in [[Resources]] — with the concepts in place, they're readable,
  and they tell you *why* the language is shaped this way.
- Teach it. Run a brown-bag on Swift 6 migration for your team. Teaching is the test.
