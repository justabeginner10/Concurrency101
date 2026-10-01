# Progress

> Roadmap: [[00 - Roadmap]] · Drills: [[Drills - How They Work]] · Lab: [[Lab Setup]]

**Restructured:** 2026-09-22 — from read→quiz to build→break→explain.
**Original start:** 2026-08-07
**Current position:** Phase B, module 03.

---

## Status board

A module is ✅ only when its drill's "Done when" boxes are all ticked. Reading it doesn't count.

| # | Module | Drill | Status | Date |
| :--- | :--- | :--- | :--- | :--- |
| — | [[Lab Setup]] | — | ⬜ | |
| 01 | [[01 - Mental Model]] | *(pre-restructure)* | ✅ notes read | |
| 02 | [[02 - Async Await Deep Dive]] | *(pre-restructure)* | ✅ notes read | |
| **03** | **[[03 - Isolation - The Core Concept]]** | [[Drill 03 - Reading Isolation]] | ⬜ **next** | |
| 04 | [[04 - Actors]] | [[Drill 04 - The Reentrancy Bug]] | ⬜ | |
| 05 | [[05 - MainActor and Global Actors]] | [[Drill 05 - MainActor Propagation]] | ⬜ | |
| 06 | [[06 - Sendable and Data-Race Safety]] | [[Drill 06 - Making It Sendable]] | ⬜ | |
| 07 | [[07 - Bridging Legacy Code]] | [[Drill 07 - Wrap a Delegate]] | ⬜ | |
| 08 | [[08 - Structured Concurrency]] | [[Drill 08 - Parallel Fetch]] | ⬜ | |
| 09 | [[09 - Tasks, Cancellation and Priority]] | [[Drill 09 - Cancel It Properly]] | ⬜ | |
| 10 | [[10 - AsyncSequence and AsyncStream]] | [[Drill 10 - Build a Stream]] | ⬜ | |
| 11 | [[11 - Swift 6.2 and Modern Defaults]] | [[Drill 11 - Same Code, Four Behaviours]] | ⬜ | |
| 12 | [[12 - Migrating to Swift 6]] | [[Drill 12 - Migrate One Module]] | ⬜ | |
| 13 | [[13 - Testing Concurrent Code]] | [[Drill 13 - Test the Untestable]] | ⬜ | |
| 🏁 | [[Capstone]] | — | ⬜ | |

**Legend:** ⬜ not started · 📖 reading · 🔨 drill in progress · ✅ drill complete

> Modules 01 and 02 are marked "notes read" rather than ✅ because they predate the drill
> format. Worth revisiting §4 of module 02 (reentrancy) *after* module 04 — it's the one topic
> that only lands the second time, once you've seen an actor.

---

## ⭐ Error Log

**The most valuable thing in this folder.** Every wrong prediction, every compiler error you
couldn't decode, every bug you had to look up. By module 13 this *is* your personal reference —
and it's the raw material for the write-up in [[Capstone]].

Format: what you predicted, what happened, why you were wrong. Be honest; a sanitised log is
worthless.

| Date | Module | I predicted… | Actually… | Why I was wrong |
| :--- | :--- | :--- | :--- | :--- |
| | | | | |

---

## Compiler errors I couldn't decode on sight

Paste the error verbatim, then the fix. After ~10 entries, patterns appear and you'll start
recognising families rather than individual messages.

| Error (verbatim) | What it actually meant | Fix |
| :--- | :--- | :--- |
| | | |

---

## Migration scoreboard

For [[Drill 12 - Migrate One Module]] and real work afterwards.

| Module | Warnings before | After | `@unchecked` added | Date |
| :--- | :--- | :--- | :--- | :--- |
| | | | | |

---

## Reentrancy sightings

`check → await → act` patterns found in real code. Include the repo and file.

| Where | The pattern | Actually a bug? | Fixed? |
| :--- | :--- | :--- | :--- |
| | | | |

---

## Questions to come back to

Things that didn't quite land. Revisit after the next module — most resolve themselves once the
next concept is in place.

- [ ]
