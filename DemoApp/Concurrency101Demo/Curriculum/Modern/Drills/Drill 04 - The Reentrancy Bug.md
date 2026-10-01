# Drill 04 — The Reentrancy Bug

> Module: [[04 - Actors]] · How drills work: [[Drills - How They Work]]
> **Time:** ~45 min · **File:** `Sources/ConcurrencyLab/Drill04.swift`
> **This is the most important drill in the curriculum.** Don't skim it.

---

## Part 1 — Build: the naive cache

```swift
import Foundation

actor ImageLoader {
    private var cache: [String: Data] = [:]
    private(set) var downloadCount = 0

    func load(_ key: String) async throws -> Data {
        if let hit = cache[key] {
            print("  cache hit: \(key)")
            return hit
        }
        let data = try await download(key)
        cache[key] = data
        return data
    }

    private func download(_ key: String) async throws -> Data {
        downloadCount += 1
        print("  ⬇️  DOWNLOADING \(key)  (count now \(downloadCount))")
        try await Task.sleep(for: .milliseconds(300))
        return Data(key.utf8)
    }
}
```

**Predict, before running:** you call `load("cat")` ten times concurrently. How many downloads
print?

```swift
let loader = ImageLoader()
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10 {
        group.addTask { _ = try? await loader.load("cat") }
    }
}
print("total downloads: \(await loader.downloadCount)")
```

---

## Part 2 — Break: you already did

You should see **10 downloads**, not 1.

Before reading further, answer in one sentence: *the actor serialised every access to `cache`
correctly — so why did the cache not work?*

<details><summary>Answer</summary>

Because `await download(key)` is a suspension point. Each of the ten callers ran the cache
check, found nothing, and suspended — all before any of them reached the line that stores the
result. The actor prevented a *data race* on `cache` (no corruption, no torn reads) but it did
nothing to protect the *invariant* "check-then-store is atomic", because that sequence spans a
suspension. Actors serialise access; they do not serialise operations.
</details>

Now make it worse, so the failure mode is unmistakable:

1. Add `try await Task.sleep(for: .milliseconds(100))` between the cache check and the
   download. More callers pile into the gap.
2. Change `download` to increment a counter *and* append to an array, then print the array. See
   the duplicated work accumulate.
3. Replace "download" with "charge the user £5". Sit with that for a second. This is the bug in
   its production form.

---

## Part 3 — Fix it three ways

**Fix A — re-check after the await.** Cheapest. Does it stop duplicate downloads?

```swift
let data = try await download(key)
if let winner = cache[key] { return winner }
cache[key] = data
return data
```

Run it. Predict first: how many downloads now?

<details><summary>Answer</summary>

Still 10. The re-check makes the *state* consistent (everyone ends up with the same value, no
lost update) but every caller still performed the download. Fix A is about correctness of
state, not about avoiding duplicate work. Knowing which problem you're solving is the point.
</details>

**Fix B — cache the task.** ✅ The real fix.

```swift
actor ImageLoader {
    private enum Entry { case loading(Task<Data, Error>), ready(Data) }
    private var cache: [String: Entry] = [:]

    func load(_ key: String) async throws -> Data {
        switch cache[key] {
        case .ready(let d):    return d
        case .loading(let t):  return try await t.value
        case nil:              break
        }
        let task = Task { try await self.download(key) }
        cache[key] = .loading(task)          // ← before ANY await
        do {
            let d = try await task.value
            cache[key] = .ready(d)
            return d
        } catch {
            cache[key] = nil
            throw error
        }
    }
}
```

Run it. **1 download.** Now the important question — answer before reading:

*Why is `cache[key] = .loading(task)` safe here, when the cache check in the naive version
wasn't?*

<details><summary>Answer</summary>

Because between `Task { }` and `cache[key] = .loading(task)` there is **no suspension point**.
Within a single isolation domain, code between two `await`s runs atomically — no other job on
this actor can interleave. The naive version's check and store were separated by an `await`,
so they weren't atomic. Same actor, same protection; the difference is entirely about where the
suspension points are.
</details>

**Fix C — a `Mutex`.** Implement the same cache with `Mutex` from `Synchronization` instead of
an actor. What changes for callers? Which would you ship, and why?

<details><summary>Discussion</summary>

With a `Mutex`, `load` can't be synchronous anyway (the download is async), so the mutex only
guards the dictionary — which means you're back to check-then-store across a suspension, and
you have to build the task-caching logic yourself with more care. For this problem the actor is
the better tool. `Mutex` wins when the critical section contains **no** `await` — a counter, a
flag, a small dictionary of already-computed values.
</details>

---

## Part 4 — Find them in the wild

Open a real codebase you work on. Search for `await` inside actor or `@MainActor` methods. For
each hit, ask the §4 question: *what did I assume before this line that another call could
invalidate?*

Write down every genuine `check → await → act` you find. You are looking for:

- `if !isLoading { isLoading = true; await ...; isLoading = false }`
- `guard cache[x] == nil else { return }` followed by an await
- `let n = count; await save(); count = n + 1`

Finding one in production code you own is the real completion of this drill.

---

## Done when

- [ ] You produced 10 downloads and can explain why in one sentence without notes
- [ ] Fix A implemented, and you can say what it does and doesn't solve
- [ ] Fix B implemented, and you can explain why the pre-`await` store is atomic
- [ ] You searched a real codebase and wrote down what you found
