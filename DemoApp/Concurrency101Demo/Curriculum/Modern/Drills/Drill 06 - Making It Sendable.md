# Drill 06 — Making It Sendable

> Module: [[06 - Sendable and Data-Race Safety]] · How drills work: [[Drills - How They Work]]
> **Time:** ~50 min · **Requires:** Thread Sanitizer on

---

## Part 1 — Build: six broken types

Each of these fails to compile when sent across a boundary. Fix each with the **cheapest
correct** option from the §3 decision tree — and write down *which branch* you used.

```swift
// 1
class Settings {
    var theme: String = "dark"
    var fontSize: Int = 14
}

// 2
final class Config {
    let apiURL: URL
    let timeout: TimeInterval
    init(apiURL: URL, timeout: TimeInterval) { self.apiURL = apiURL; self.timeout = timeout }
}

// 3
final class EventBuffer {
    private var events: [String] = []
    func add(_ e: String) { events.append(e) }
    func drain() -> [String] { defer { events = [] }; return events }
}

// 4
final class ProfileViewModel {
    var name: String = ""
    var avatar: UIImage?
    func update(_ n: String) { name = n }
}

// 5
struct Payload {
    let id: UUID
    let handler: () -> Void        // why does this break the struct?
}

// 6
final class Metrics {
    static let shared = Metrics()
    private var counts: [String: Int] = [:]
    func bump(_ k: String) { counts[k, default: 0] += 1 }
}
```

Test each fix by actually sending it:

```swift
actor Sink { func consume<T: Sendable>(_ x: T) { } }
let sink = Sink()
await sink.consume(yourFixedType)
```

<details><summary>Intended answers</summary>

1. **struct** — it's plain data, nothing needs reference semantics.
2. **`final class ... : Sendable`** — already immutable, just needs the annotation.
3. **actor** — shared mutable state by design.
4. **`@MainActor`** — UI-owned; isolation gives `Sendable` for free.
5. The closure isn't `@Sendable`, so the struct isn't. Either mark it
   `let handler: @Sendable () -> Void` or — better — ask whether the closure should be
   crossing a boundary at all.
6. `Mutex`-backed `final class: Sendable` (keeps `bump` synchronous), or an `actor` (makes
   every caller `await`). Both correct; the trade-off is §3.2 of
   [[12 - Migrating to Swift 6]] and is worth thinking through properly.
</details>

---

## Part 2 — Break: lie to the compiler, then get caught

Take #3 and "fix" it the lazy way:

```swift
final class EventBuffer: @unchecked Sendable {     // ⚠️ no synchronisation at all
    private var events: [String] = []
    func add(_ e: String) { events.append(e) }
}
```

It compiles. Now hammer it:

```swift
let buffer = EventBuffer()
await withTaskGroup(of: Void.self) { group in
    for i in 0..<1000 {
        group.addTask { buffer.add("event-\(i)") }
    }
}
```

Run with **Thread Sanitizer on**. Read the report: two threads, the exact stack, the exact
write.

This is what `@unchecked Sendable` without a lock actually means — you didn't fix anything, you
turned off the alarm. Keep this output; it's the most persuasive thing you can show a colleague
who wants to clear a migration backlog with `@unchecked`.

Now add the lock and re-run:

```swift
final class EventBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    func add(_ e: String) { lock.withLock { events.append(e) } }
}
```
TSan goes quiet. **That** is a legitimate `@unchecked Sendable`.

---

## Part 3 — Region isolation

Prove the compiler is smarter than "is the type Sendable":

```swift
final class NotSendable { var x = 0 }

func transfer() async {
    let thing = NotSendable()
    thing.x = 42
    await sink.consume(thing)      // ✅ compiles — why?
}

func transferBad() async {
    let thing = NotSendable()
    await sink.consume(thing)
    thing.x = 99                   // ❌ now it doesn't — why?
}
```

Explain the difference in one sentence before reading the module's §5.

---

## Done when

- [ ] All six fixed, each with the branch of the tree written next to it
- [ ] You caught a real race with Thread Sanitizer and read the report
- [ ] The locked version runs clean
- [ ] You can explain region-based isolation from the two `transfer` functions
