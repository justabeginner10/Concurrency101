# Drill 11 — Same Code, Four Behaviours

> Module: [[11 - Swift 6.2 and Modern Defaults]] · How drills work: [[Drills - How They Work]]
> **Time:** ~25 min · **Short, and it permanently fixes "why is this on main?"**

---

## Part 1 — Verify the table

One file, four declarations, called from a `@MainActor` context:

```swift
func plain() async               { here("1 plain") }
nonisolated func nonIso() async  { here("2 nonisolated") }
@concurrent nonisolated func conc() async { here("3 @concurrent") }

@MainActor
func run() async {
    await plain()
    await nonIso()
    await conc()
    await Task.detached { await plain() }.value      // row 4
}
```

Fill this in from §5 of the module **before running**:

| Declaration | Predicted (Default=MainActor) | Actual | Predicted (Default=nonisolated) | Actual |
| :--- | :--- | :--- | :--- | :--- |
| `plain()` | | | | |
| `nonIso()` | | | | |
| `conc()` | | | | |
| `plain()` via `Task.detached` | | | | |

Run it twice — once with each `Default Actor Isolation` setting. Eight cells, all verified by
you.

---

## Part 2 — The row that proves the principle

Row 4 with `Default = MainActor` runs on **main**, despite `Task.detached` inheriting nothing.

Explain why in one sentence before reading on.

<details><summary>Answer</summary>

Because the module default made `plain()` implicitly `@MainActor` — the isolation is baked into
the *declaration*. `Task.detached` inherits no *context*, but it can't override a declaration's
own isolation, because isolation is a static property of the declaration rather than something
passed down at runtime.

If you can say this without hesitating, module 03 landed.
</details>

---

## Part 3 — The package boundary

Move the same file into a local SPM package with no isolation settings, and call it from the
app target.

Predict what changes. Then check the build warnings — you'll likely get new `Sendable` errors
that didn't exist when the code lived in the app.

**This is the thing that bites during modularisation**, and knowing it in advance saves a
confusing afternoon. Write down what you'd set for:

- a UI component package
- a networking package
- a model/domain package

(Answers in §7 of the module — but decide first.)

---

## Part 4 — `@concurrent` where it doesn't belong

```swift
@concurrent nonisolated func fetchJSON(_ url: URL) async throws -> Data {
    try await URLSession.shared.data(from: url).0
}
```

Measure this against the same function without `@concurrent`. Is it faster? Why not?

<details><summary>Answer</summary>

No — it's marginally slower. `URLSession` already suspends without occupying a thread, so
there was never any thread to free. `@concurrent` just added two hops (out of the caller's
executor and back) for no benefit, and forced the arguments and return to be `Sendable`.

`@concurrent` is for **CPU-bound** work. I/O is already non-blocking.
</details>

---

## Done when

- [ ] All eight cells predicted and verified
- [ ] You can explain row 4 without looking
- [ ] You moved code into a package and saw the behaviour change
- [ ] You measured `@concurrent` on I/O and know why it didn't help
