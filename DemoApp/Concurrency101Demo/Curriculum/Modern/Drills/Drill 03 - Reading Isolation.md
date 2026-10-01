# Drill 03 — Reading Isolation

> Module: [[03 - Isolation - The Core Concept]] · How drills work: [[Drills - How They Work]]
> **Time:** ~40 min · **File:** `Sources/ConcurrencyLab/Drill03.swift`

---

## Part 1 — Build: the prediction table

Paste this into the lab. **Before running**, fill in the prediction column for every `here()`
call. Write it down.

```swift
import Foundation

@MainActor
final class MainThing {
    func direct() { here("1  MainThing.direct") }

    func spawnTask() {
        Task { here("2  Task inside @MainActor") }
    }

    func spawnDetached() {
        Task.detached { here("3  detached inside @MainActor") }
    }

    nonisolated func nonIso() { here("4  nonisolated member") }
}

actor ActorThing {
    func direct() { here("5  ActorThing.direct") }

    func spawnTask() {
        Task { here("6  Task inside actor") }
    }

    nonisolated func nonIso() { here("7  nonisolated actor member") }
}

nonisolated func freeFunc() { here("8  free nonisolated func") }

nonisolated func freeFuncSpawning() {
    here("9  free func body")
    Task { here("10 Task inside free func") }
}

@main
struct Drill03 {
    static func main() async throws {
        let m = MainThing()
        await m.direct()
        await m.spawnTask()
        await m.spawnDetached()
        m.nonIso()

        let a = ActorThing()
        await a.direct()
        await a.spawnTask()
        a.nonIso()

        freeFunc()
        freeFuncSpawning()

        try await Task.sleep(for: .milliseconds(500))   // let spawned tasks print
    }
}
```

| # | Prediction (MAIN / bg) | Actual | Why |
| :--- | :--- | :--- | :--- |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |
| 7 | | | |
| 8 | | | |
| 9 | | | |
| 10 | | | |

Now run it.

> ⚠️ **Check your `Default Actor Isolation` setting first.** If it's `MainActor`, the
> nonisolated-looking rows will surprise you — and that surprise is the lesson. Run it once
> each way.

---

## Part 2 — Break: force each hop to be visible

1. Change `freeFuncSpawning` to be `@MainActor`. Re-predict row 10. Why did it move?
2. Add `@concurrent` to a `nonisolated async` function and call it from `MainThing`. Where does
   it run now, and why is that the *only* reliable way to leave?
3. Take row 3 (`Task.detached` inside `@MainActor`) and make its body call `self.direct()`.
   The compiler now demands `await`. **Explain what that `await` is buying you** — in one
   sentence, before reading on.

<details><summary>Answer to 3</summary>

The detached closure is nonisolated, so calling a `@MainActor` method crosses an isolation
boundary. The `await` marks the hop: the runtime must enqueue the call on the main actor's
executor and suspend until it's your turn. The `await` is your visible evidence in the source
that a domain change happens here.
</details>

---

## Part 3 — Explain: the inference hunt

For each of these, state the isolation **and which vector from §3 of the module put it there**
(explicit / enclosing type / protocol / superclass / module default / lexical capture):

```swift
// a
struct Row: View { var body: some View { Text("hi") } }

// b
final class Coordinator: UIViewControllerRepresentable { }

// c
extension MainThing {
    func helper() { }
}

// d
protocol Loadable { func load() async }
struct Loader: Loadable { func load() async { } }

// e — in a Swift package with no isolation settings
func process(_ x: Int) async -> Int { x * 2 }
```

Then verify every answer by Option-clicking the symbol in Xcode. **Any you got wrong goes in
the Error Log.**

---

## Done when

- [ ] All ten rows predicted, run, and explained
- [ ] Run once with `Default Actor Isolation = MainActor` and once with `nonisolated`, and you
      can state which rows changed and why
- [ ] All five inference questions answered and verified with Option-click
- [ ] Wrong predictions logged in [[Progress]]
