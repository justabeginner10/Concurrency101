import Dispatch
import Concurrency101

/// WARNING: This process is supposed to hang.
///
/// Do not run this as your default example. Do not call it from tests.
///
///     swift run DeadlockOnPurposeExample
///
/// Lesson: `queue.sync` parks *this* thread until the block runs on `queue`.
/// The main queue is serial and bound to the main thread. If the main thread
/// is waiting for the main queue, the block can never start.
///
/// GCD: `DispatchQueue.main.sync { }`
/// Swift Concurrency: there is no equivalent — `await` suspends a task; it
/// does not block a thread.
///
/// Graduation: delete `import Concurrency101` and rewrite this file using
/// DispatchQueue / Task / @MainActor. If you cannot, reread the mapped note.

print("=== DeadlockOnPurposeExample ===")
print("About to call Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main)")
print("from the main thread. The next print will never appear.")
print("Press Ctrl+C to exit.")
print("")

Concurrency101.GCD.Blocking.blockThisThreadUntilFinished(on: .main) {
    print("this never prints if called on the main thread")
}

print("this never prints either")
