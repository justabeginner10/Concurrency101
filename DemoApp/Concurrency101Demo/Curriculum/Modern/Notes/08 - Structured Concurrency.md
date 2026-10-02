# Module 08 — Structured Concurrency

> Roadmap: [[00 - Roadmap]] · Terms: [[Glossary]] · Prev: [[07 - Bridging Legacy Code]] ·
> Next: [[09 - Tasks, Cancellation and Priority]]
> **Goal:** run work in parallel without losing track of errors or cancellation.
> Drill: [[Drill 08 - Parallel Fetch]]

---

## 1. The idea

> **Structured** means a child task's lifetime is bounded by a syntactic scope. The parent
> cannot return until every child has finished.

That single constraint buys you four guarantees, for free:

- **No leaks.** Children can't outlive the scope; the scope won't exit while they run.
- **Errors propagate.** A child throwing surfaces at the parent's `await`.
- **Cancellation flows down.** Cancel the parent, every descendant is cancelled.
- **Priority flows down.** Children inherit, and get escalated if the parent is.

`Task { }` is **unstructured** — it escapes the scope, and you get none of the above unless you
build it yourself. That's [[09 - Tasks, Cancellation and Priority]]. Prefer structured; reach
for unstructured only when you genuinely need work to outlive the current scope.

```mermaid
graph TD
    P["parent task"] --> C1["async let a"]
    P --> C2["async let b"]
    P --> G["withTaskGroup"]
    G --> G1["child 1"]
    G --> G2["child 2"]
    G --> G3["child 3"]
    P -. "cancel flows down" .-> C1
    P -. .-> C2
    P -. .-> G
    G -. .-> G1
    style P fill:#2d6a4f,color:#fff
```

---

## 2. `async let` — a fixed, known set

```swift
func loadDashboard() async throws -> Dashboard {
    async let profile = api.fetchProfile()      // starts NOW
    async let feed    = api.fetchFeed()         // starts NOW
    async let badges  = api.fetchBadges()       // starts NOW

    return try await Dashboard(
        profile: profile, feed: feed, badges: badges
    )
}
```

Three requests in the time of the slowest, not the sum. Compare:

```swift
let profile = try await api.fetchProfile()   // 300ms
let feed    = try await api.fetchFeed()      // 300ms  → 900ms total
let badges  = try await api.fetchBadges()    // 300ms
```

**Sequential `await`s are sequential.** Concurrency is opt-in — this is the single most common
missed optimisation in real async code, and it's invisible because the code looks fine.

Rules worth knowing:

- The child **starts at the declaration**, not at the `await`.
- You do not have to *read* every `async let`. If you never `await` it, the scope cancels and
  joins it at exit — safe, result discarded. If you care about the value or the error, `await`
  it on every path that needs it.
- If one throws, the others are cancelled automatically as the scope unwinds.
- `async let` is for a **statically known** number of children. Dynamic count → task group.

---

## 3. Task groups — a dynamic set

```swift
func loadAll(_ ids: [String]) async throws -> [Item] {
    try await withThrowingTaskGroup(of: Item.self) { group in
        for id in ids {
            group.addTask { try await api.fetchItem(id) }
        }

        var items: [Item] = []
        for try await item in group {        // results arrive in COMPLETION order
            items.append(item)
        }
        return items
    }
}
```

> ⚠️ **Results arrive in completion order, not submission order.** If you need input order,
> carry the index:

```swift
try await withThrowingTaskGroup(of: (Int, Item).self) { group in
    for (i, id) in ids.enumerated() {
        group.addTask { (i, try await api.fetchItem(id)) }
    }
    var buffer = [Item?](repeating: nil, count: ids.count)
    for try await (i, item) in group { buffer[i] = item }
    return buffer.compactMap { $0 }
}
```

### Which group to use

| Function | Use when |
| :--- | :--- |
| `withTaskGroup` | Children can't throw |
| `withThrowingTaskGroup` | Children can throw; first error cancels the rest |
| `withDiscardingTaskGroup` | Fire-and-forget children, no results (efficient — no result buffer) |
| `withThrowingDiscardingTaskGroup` | Same, but can throw |

The discarding variants matter for long-lived work like a server accept-loop or a batch of
uploads whose results you don't collect — a normal group retains every result until the scope
ends, which for unbounded work is a leak.

### Error semantics

In a throwing group, the first child to throw causes the group to cancel the remaining
children and rethrow. To collect rather than abort:

```swift
try await withTaskGroup(of: Result<Item, Error>.self) { group in
    for id in ids {
        group.addTask {
            do { return .success(try await api.fetchItem(id)) }
            catch { return .failure(error) }
        }
    }
    // now every child reports, none cancel each other
}
```

---

## 4. Limiting concurrency ⚠️

`addTask` in a loop over 5,000 items starts 5,000 tasks. Tasks are cheap, but the *work* isn't
— 5,000 simultaneous URL requests will be throttled, time out, or exhaust memory.

The sliding-window idiom:

```swift
func fetchAll(_ urls: [URL], maxConcurrent: Int = 6) async throws -> [Data] {
    try await withThrowingTaskGroup(of: Data.self) { group in
        var results: [Data] = []
        var index = 0

        // prime the window
        while index < min(maxConcurrent, urls.count) {
            let url = urls[index]
            group.addTask { try await download(url) }
            index += 1
        }

        // for each completion, start one more
        while let data = try await group.next() {
            results.append(data)
            if index < urls.count {
                let url = urls[index]
                group.addTask { try await download(url) }
                index += 1
            }
        }
        return results
    }
}
```

Memorise this shape. It's the correct answer to "download N things" in production code, and
the naive version works perfectly in your tests with 3 items and falls over with 3,000.

---

## 5. Child task rules

- A child inherits priority, task-locals and cancellation state from its parent.
- A child does **not** inherit the parent's actor isolation — `addTask` closures are
  `@Sendable` and therefore nonisolated (§3.6, [[03 - Isolation - The Core Concept]]).
- Values passed in and results returned must be `Sendable`.
- The group scope won't return until all children complete, **even if you stop consuming
  results**. Leaving the scope early cancels the rest and then waits for them.

That last point surprises people: `return` from inside a group body doesn't abandon the
children, it cancels and awaits them. Structured concurrency has no way to leak a child, which
is exactly what makes it worth using.

---

## 6. `async let` vs group vs `Task`

| | `async let` | Task group | `Task { }` |
| :--- | :--- | :--- | :--- |
| Count | Fixed, known | Dynamic | One |
| Structured | ✅ | ✅ | ❌ |
| Auto-cancel on parent cancel | ✅ | ✅ | ❌ (inherits at creation only) |
| Errors propagate to caller | ✅ | ✅ | ❌ (must handle inside) |
| Outlives the scope | ❌ | ❌ | ✅ |
| Typical use | 2–4 parallel fetches | N parallel fetches | Entering async from sync |

> Decision rule: **structured unless the work must outlive the scope.** If you're writing
> `Task { }` inside an `async` function, stop and check — you almost always wanted `async let`
> or a group, and you've just opted out of error propagation and cancellation.

---

## 7. Pitfalls

**7.1 — Thinking sequential `await`s are parallel.** They aren't. §2.

**7.2 — `async let` inside a loop.** It doesn't accumulate; each iteration's child is awaited
(or cancelled) at the end of its scope. Use a group.

**7.3 — Unbounded `addTask`.** §4.

**7.4 — Assuming completion order is submission order.** §3.

**7.5 — CPU-bound work in a group expecting parallelism.** You get at most one thread per core,
and if the children are main-actor-isolated you get **one**, serialised, with no parallelism at
all. Parallel CPU work must be `nonisolated`, and under Xcode 26 defaults usually `@concurrent`.

**7.6 — Swallowing a cancellation error.** `CancellationError` propagating out of a group is
normal and means the system is working. Catching it and returning a default value turns a
clean cancel into a silent wrong answer.

---

## 8. Drill gate

→ **[[Drill 08 - Parallel Fetch]]**

Build the same fetch three ways — sequential, `async let`, task group — and **measure all
three**. Then add the concurrency limiter and watch the timing curve change. Numbers, not
intuition: predict each before you run it, and log the ones you got wrong.
