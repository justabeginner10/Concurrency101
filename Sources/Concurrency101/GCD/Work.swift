import Dispatch

extension Concurrency101.GCD {
    /// Wraps `work` so you can cancel it *before it starts*, or attach a
    /// notification when it finishes.
    ///
    /// Returns a real `DispatchWorkItem` so `queue.async(execute:)`, `notify`,
    /// and `cancel` stay visible. Graduation means using that type directly.
    ///
    /// The caller waits: **no**.
    ///
    /// GCD: `DispatchWorkItem(block:)`.
    ///
    /// Swift Concurrency: `Task` + `Task.checkCancellation()` / `isCancelled`.
    ///
    /// Teaching trap: cancellation is **cooperative**. If the block is already
    /// running and never checks a flag, `cancel()` does not stop it.
    ///
    /// ```swift
    /// let item = Concurrency101.GCD.makeCancellableWork { loadFeed() }
    /// let lane = Concurrency101.GCD.makePrivateSerialLane(label: "com.concurrency101.example.feed")
    /// item.cancel()
    /// lane.async(execute: item) // loadFeed will not run
    /// ```
    ///
    /// Already running:
    ///
    /// ```swift
    /// let item = Concurrency101.GCD.makeCancellableWork {
    ///     Thread.sleep(forTimeInterval: 2) // cancel() will not abort this
    /// }
    /// lane.async(execute: item)
    /// item.cancel()
    /// ```
    ///
    /// - Parameter work: The body of the work item.
    /// - Returns: A `DispatchWorkItem` you submit yourself.
    ///
    /// - SeeAlso: [DispatchWorkItem](https://developer.apple.com/documentation/dispatch/dispatchworkitem)
    public static func makeCancellableWork(_ work: @escaping () -> Void) -> DispatchWorkItem {
        DispatchWorkItem(block: work)
    }
}
