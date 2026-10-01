# Drill 12 — Migrate One Module

> Module: [[12 - Migrating to Swift 6]] · How drills work: [[Drills - How They Work]]
> **Time:** a few hours, spread out · **This is the real one.**

---

## The task

Take a module from an app **you actually own** — not a toy, not a sample project — and get it
to Swift 6 language mode with **zero `@unchecked Sendable`**.

Good first candidates, in order: your model layer, then networking, then a single feature
module. Don't start with the app target.

---

## Part 1 — Baseline

```bash
# set SWIFT_STRICT_CONCURRENCY = complete, keep SWIFT_VERSION = 5.0, then:
xcodebuild -scheme YourScheme 2>&1 | grep -c "warning:"
```

Record it:

| Metric | Before | After |
| :--- | :--- | :--- |
| Concurrency warnings | | 0 |
| `@unchecked Sendable` | | 0 |
| `nonisolated(unsafe)` | | |
| `MainActor.assumeIsolated` | | |
| Files changed | — | |
| Time spent | — | |

---

## Part 2 — The four passes

Work in this order. **Commit after each pass** so you can see the shape of the work and bisect
if something breaks.

**Pass 1 — annotate, don't restructure.** Add `@MainActor` where code already runs on main.
Add `: Sendable` to types that are already immutable. Zero behaviour change. Expect this to
clear 60–70% of warnings.

**Pass 2 — globals and singletons.** §3.1 and §3.2 of the module. Real decisions here: for each
singleton, choose actor vs `Mutex`-backed class vs `@MainActor`, and **write down why**. The
`async`-cascade question (does making this an actor force `await` through 200 call sites?) is
the deciding factor more often than purity.

**Pass 3 — delegates and SDK boundaries.** `@preconcurrency`, `assumeIsolated`,
`Task { @MainActor in }`. §3.3 and §3.5.

**Pass 4 — the remainder.** Whatever's left needs actual design work. It should now be a short,
visible list instead of a wall — which was the whole point of passes 1–3.

---

## Part 3 — Flip and verify

1. `SWIFT_VERSION = 6.0`. If passes 1–4 were honest, this is a no-op.
2. Run the test suite.
3. Run it again with `-enableThreadSanitizer YES`.
4. Run the app and exercise the migrated module by hand.

Step 3 is not optional. The compiler proves what it can see; TSan finds what you promised.

---

## Part 4 — Write it up

Produce a short ADR (see the `engineering:architecture` skill) covering:

- Which module and why it went first
- The singleton decisions from pass 2, with the reasoning
- Anything you couldn't migrate, and what it's blocked on
- What you'd do differently on the next module

This write-up is the thing you'll actually reference when you migrate module two — and it's a
genuinely strong interview artefact. "Here's a migration I led and the trade-offs I chose" is a
much better answer than "yes I know Swift 6."

---

## Done when

- [ ] Module builds in Swift 6 language mode
- [ ] Zero `@unchecked Sendable`, or each remaining one has a comment, a ticket, and a reason
- [ ] Tests pass, including under Thread Sanitizer
- [ ] The table in Part 1 is filled in
- [ ] The ADR is written
