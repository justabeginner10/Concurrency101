# Drill 05 — MainActor Propagation

> Module: [[05 - MainActor and Global Actors]] · How drills work: [[Drills - How They Work]]
> **Time:** ~35 min · **Target:** the SwiftUI app, not the CLI

---

## Part 1 — Build: find the invisible isolation

Create these with **no `@MainActor` written anywhere**. For each, determine whether it's
main-isolated and name the vector (protocol / superclass / module default / capture).

```swift
import SwiftUI

// a
struct Card: View {
    var body: some View { Text("hi") }
    func helper() { here("a Card.helper") }
}

// b
final class OldVC: UIViewController {
    func refresh() { here("b OldVC.refresh") }
}

// c
final class Plain {
    func work() { here("c Plain.work") }
}

// d
@Observable final class Model {
    var items: [String] = []
    func load() { here("d Model.load") }
}

// e
protocol Presenting { func present() }
final class Presenter: Presenting {
    func present() { here("e Presenter.present") }
}
```

Predict all five. Then verify **two ways**: Option-click each symbol, and run them from a
`Task.detached` to see where they actually execute.

Now flip `Default Actor Isolation` to `nonisolated` in Build Settings and redo it. Which
answers changed? That difference is your module default, made visible.

---

## Part 2 — Break: crash `assumeIsolated`

```swift
nonisolated func pretendDelegateCallback() {
    MainActor.assumeIsolated {
        print("touching main-actor state")
    }
}

// call it correctly
Task { @MainActor in pretendDelegateCallback() }     // fine

// now call it wrong
Task.detached { pretendDelegateCallback() }          // 💥
```

Run the second one. Read the crash. **This is the cost of getting `assumeIsolated` wrong**, and
it's why it's a last resort rather than a convenient way to silence an error.

Then fix the same callback three other ways and rank them:
- `Task { @MainActor in ... }`
- marking the function `@MainActor`
- `await MainActor.run { ... }`

Which changes *when* the work happens? (Two of them do.)

---

## Part 3 — The spread experiment

```swift
@MainActor protocol Coordinating {
    func start()
}

final class AppCoordinator: Coordinating {
    let analytics = Analytics()        // is THIS main-isolated?
    func start() { }
    func backgroundWork() { }          // and this?
}
```

Predict, then verify: does conforming to a `@MainActor` protocol isolate the **whole type**, or
only the requirement?

<details><summary>Answer</summary>

The whole type. Conformance to a globally-isolated protocol infers that isolation for the
conforming type when the type has no explicit isolation of its own — so `backgroundWork()` and
the `analytics` property are main-isolated too, with nothing in the source saying so.

This is the single biggest source of "why is this on the main actor?" in real apps, and it's
why `UIViewController` and `View` conformance quietly isolate most of an app's code. To opt a
member out, mark it `nonisolated` explicitly.
</details>

---

## Done when

- [ ] All five types classified correctly, verified by Option-click **and** by running
- [ ] You ran the whole file under both `Default Actor Isolation` settings and can name what
      changed
- [ ] You crashed `assumeIsolated` on purpose and read the message
- [ ] You can state the protocol-conformance spreading rule from memory
