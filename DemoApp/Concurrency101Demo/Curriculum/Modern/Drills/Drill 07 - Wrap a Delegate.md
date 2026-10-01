# Drill 07 — Wrap a Delegate

> Module: [[07 - Bridging Legacy Code]] · How drills work: [[Drills - How They Work]]
> **Time:** ~50 min

---

## Part 1 — Build: a cancellable continuation

Here's a deliberately old-fashioned API. Wrap it.

```swift
final class LegacyDownloader {
    private var work: DispatchWorkItem?

    func download(_ name: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let item = DispatchWorkItem {
            completion(.success(Data(name.utf8)))
        }
        work = item
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func cancel() {
        work?.cancel()
        work = nil
    }
}
```

Requirements:
1. `func download(_ name: String) async throws -> Data`
2. Cancelling the task must cancel the underlying work (`withTaskCancellationHandler`)
3. Every callback path resumes **exactly once**

Test it:
```swift
let task = Task { try await downloader.download("cat") }
try await Task.sleep(for: .milliseconds(100))
task.cancel()
// what happens? what SHOULD happen?
```

---

## Part 2 — Break: hang your program

Introduce the classic bug:

```swift
try await withCheckedThrowingContinuation { c in
    legacy.download(name) { result in
        guard case .success(let data) = result else { return }   // 💀 no resume on failure
        c.resume(returning: data)
    }
}
```

Force the failure path. **Your program hangs. Forever. No crash, no log, no stack.**

Sit with that for a moment — this is what a continuation leak looks like in production: a user
reporting "it just spins", no crash report, nothing in your logs.

Now make the *other* mistake:

```swift
legacy.download(name) { result in
    c.resume(returning: Data())
    c.resume(returning: Data())      // 💥
}
```
Read the "SWIFT TASK CONTINUATION MISUSE" message. Note that the **checked** continuation is
what gave you a diagnosable crash instead of memory corruption — this is why you never start
with `withUnsafeContinuation`.

Finally, add a time limit to a test around the hanging version:
```swift
@Test(.timeLimit(.minutes(1))) func doesNotHang() async throws { ... }
```
This is how you catch leaked continuations in CI instead of at 3am.

---

## Part 3 — Build: a delegate as `AsyncStream`

```swift
protocol TickerDelegate: AnyObject {
    func ticker(_ t: Ticker, didTick count: Int)
    func tickerDidFinish(_ t: Ticker)
}

final class Ticker {
    weak var delegate: TickerDelegate?
    private var timer: Timer?
    private var count = 0

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            count += 1
            delegate?.ticker(self, didTick: count)
            if count >= 10 { stop(); delegate?.tickerDidFinish(self) }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
}
```

Expose `var ticks: AsyncStream<Int>`. Requirements:
1. `for await` yields 1…10 then ends
2. `onTermination` calls `stop()`
3. Breaking out of the loop early stops the timer

**Prove requirement 3.** Add a print in `stop()`, `break` after 3 ticks, and confirm it fires.
Then delete `onTermination` and watch the timer keep running after the consumer is gone —
that's the leak, and you should see it once so you recognise it.

---

## Done when

- [ ] Continuation wrapper works and cancels properly
- [ ] You hung your own program with a missing resume, and crashed it with a double resume
- [ ] `AsyncStream` wrapper works, with cleanup proven by `break`
- [ ] You saw the leak when `onTermination` was removed
