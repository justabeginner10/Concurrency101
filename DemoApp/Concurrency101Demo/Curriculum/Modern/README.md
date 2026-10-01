# Swift Modern Concurrency

**Start here → [[00 - Roadmap]]**
**While coding → [[00 - Decision Procedure]]**

---

## What this is

A 13-module path from "I know what `await` does" to "I can ship Swift 6 code and reason about
isolation without guessing."

Restructured **2026-09-22** around one diagnosis: the gap wasn't knowledge, it was a
**feedback loop**. Reading gives you vocabulary; only a compiler gives you judgment. So every
module now ends with a drill you run in Xcode, and every drill requires you to **break
something on purpose** and predict how.

## The files

| | |
| :--- | :--- |
| [[00 - Roadmap]] | The plan — module order, phases, pacing, what "done" means |
| [[00 - Decision Procedure]] | ⭐ The three questions + symptom→fix table. **Open this while coding** |
| [[Lab Setup]] | The scratch project. Do this first |
| `Notes/` | Modules 01–13 |
| `Drills/` | One per module — build, break, explain |
| [[Progress]] | Tracker + the **Error Log** (the most valuable file here) |
| [[Glossary]] | Precise definitions |
| [[Resources]] | Curated links, with version warnings |
| `Archive/` | The pre-restructure index and quizzes |

## The order, and why

```
Phase A  01 Mental Model · 02 async/await            ✅ done
Phase B  03 Isolation ⭐ · 04 Actors · 05 MainActor · 06 Sendable
Phase C  07 Bridging · 08 Structured · 09 Cancellation · 10 Streams
Phase D  11 Swift 6.2 · 12 Migration · 13 Testing → 🏁 Capstone
```

**Phase B is the keystone.** Every confusing Swift concurrency error is an isolation error
wearing a costume, and module 03 — Isolation — didn't exist in the previous plan at all. That
absence is why the material felt like disconnected facts.

## The rule

> Turn on `SWIFT_STRICT_CONCURRENCY = complete` **before module 03**, not at the end.

With it on, every place you'd be confused becomes an error with a file, a line, and a named
value. That's the whole trick.
