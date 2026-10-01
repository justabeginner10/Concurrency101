import Concurrency101

/// WARNING: This process is supposed to hang.
///
/// Do not run this as your default example. Do not call it from tests.
///
///     swift run ModernParkThreadOnPurposeExample
///
/// Lesson: parking the main thread while waiting for MainActor work is the
/// Swift Concurrency cousin of `DispatchQueue.main.sync` from the main thread.
/// The task needs the main actor; the main thread is waiting for the task.
///
/// Swift Concurrency: semaphore around `await MainActor.run`
/// GCD: `DispatchQueue.main.sync { }`
///
/// Graduation: delete `import Concurrency101` and never write this pattern.

print("=== ModernParkThreadOnPurposeExample ===")
print("About to parkThisThreadUntilTaskFinishes waiting for waitForUI")
print("from the main thread. The next print will never appear.")
print("Press Ctrl+C to exit.")
print("")

Concurrency101.Modern.Blocking.parkThisThreadUntilTaskFinishes {
    await Concurrency101.Modern.waitForUI {
        print("this never prints if called on the main thread")
    }
}

print("this never prints either")
