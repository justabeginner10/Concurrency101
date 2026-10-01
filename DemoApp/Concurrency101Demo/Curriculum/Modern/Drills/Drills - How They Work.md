# Drills — How They Work

> Roadmap: [[00 - Roadmap]] · Lab: [[Lab Setup]] · Tracker: [[Progress]]

---

## The replacement for quizzes

The old curriculum gated each module behind a quiz. Quizzes test **recall**, and your problem
was never recall — you could already define an actor. The problem was **judgment under a
compiler error**, and only a compiler can train that.

So every module now ends with a drill, and every drill has the same three-part shape:

| Part | What it is | Why |
| :--- | :--- | :--- |
| **Build** | Write working code | Proves you can use the API |
| **Break** ⭐ | Produce a *specific* failure on purpose | Proves you understand the model |
| **Explain** | Say why, in one sentence, *before* reading the answer | Proves it's yours |

**Part 2 is the one that matters.** Anyone can copy working code. Predicting exactly how it
breaks, and why, is the thing that separates "I've read about actors" from "I can review this
PR."

---

## The rules

1. **Predict before you run.** Every time. Write the prediction down — in the drill note, in a
   comment, anywhere. An unrecorded prediction is one you'll unconsciously revise after seeing
   the output.
2. **Wrong predictions are the point.** They go in the Error Log in [[Progress]]. That log is
   the single most valuable artefact this curriculum produces; by module 13 it *is* your
   personal reference.
3. **Strict concurrency stays on.** If you turned it off to make something compile, the drill
   doesn't count. See [[Lab Setup]].
4. **Don't look up the fix first.** Ten minutes with the error, then Part 3 of
   [[00 - Decision Procedure]], then the note, then the internet. In that order.
5. **Keep the code.** Each drill lives in its own file in the lab. You will come back to them.

---

## Done means

A drill is done when all three are true:

- ✅ The build code compiles under `SWIFT_STRICT_CONCURRENCY = complete` with zero warnings
- ✅ You produced the failure the drill asks for and saw it with your own eyes
- ✅ You explained it in one sentence before reading the explanation

Not "I read the drill and it made sense."

---

## The drills

| # | Drill | Module | Produces |
| :--- | :--- | :--- | :--- |
| 03 | [[Drill 03 - Reading Isolation]] | [[03 - Isolation - The Core Concept]] | Wrong predictions about where code runs |
| 04 | [[Drill 04 - The Reentrancy Bug]] | [[04 - Actors]] | A duplicate download |
| 05 | [[Drill 05 - MainActor Propagation]] | [[05 - MainActor and Global Actors]] | An `assumeIsolated` crash |
| 06 | [[Drill 06 - Making It Sendable]] | [[06 - Sendable and Data-Race Safety]] | A TSan-caught race |
| 07 | [[Drill 07 - Wrap a Delegate]] | [[07 - Bridging Legacy Code]] | A permanent hang |
| 08 | [[Drill 08 - Parallel Fetch]] | [[08 - Structured Concurrency]] | Timing numbers, and a throttled server |
| 09 | [[Drill 09 - Cancel It Properly]] | [[09 - Tasks, Cancellation and Priority]] | Work that ignores cancellation |
| 10 | [[Drill 10 - Build a Stream]] | [[10 - AsyncSequence and AsyncStream]] | A leak, and split values |
| 11 | [[Drill 11 - Same Code, Four Behaviours]] | [[11 - Swift 6.2 and Modern Defaults]] | The four-way table, verified |
| 12 | [[Drill 12 - Migrate One Module]] | [[12 - Migrating to Swift 6]] | A real module at zero warnings |
| 13 | [[Drill 13 - Test the Untestable]] | [[13 - Testing Concurrent Code]] | A test you watched fail |
| 🏁 | [[Capstone]] | all | Something you'd put in an app |
