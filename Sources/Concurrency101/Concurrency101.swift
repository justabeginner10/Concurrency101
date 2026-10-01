/// A learning-only Swift wrapper around **Grand Central Dispatch** and
/// **Swift Concurrency**.
///
/// `Concurrency101` is a bilingual dictionary: you call a name that describes
/// *intent*, and the documentation shows the real Apple API. It is **not**
/// for production apps.
///
/// Pick a track:
///
/// - ``Concurrency101/GCD`` — queues, QoS, barriers, groups, `sync`.
/// - ``Concurrency101/Modern`` — tasks, actors, `await`, isolation.
///
/// After you can explain each helper in Apple words, delete
/// `import Concurrency101` and write `DispatchQueue` / `Task` / `@MainActor`
/// / `actor` yourself.
///
/// ### Typical hop (GCD)
///
/// ```swift
/// Concurrency101.GCD.runUserRequestedWork {
///     let image = decodeImage()
///     Concurrency101.GCD.updateUI {
///         imageView.image = image
///     }
/// }
/// ```
///
/// ### Typical hop (Swift Concurrency)
///
/// ```swift
/// let task = Concurrency101.Modern.runUserRequestedWork {
///     let image = decodeImage()
///     await Concurrency101.Modern.waitForUI {
///         imageView.image = image
///     }
/// }
/// ```
public enum Concurrency101 {
    /// Intent names for Grand Central Dispatch.
    ///
    /// Queue type controls whether submitted work may overlap. Submission type
    /// (`async` vs `sync`) controls whether the caller waits. These are
    /// different questions. See <doc:MentalModel>.
    public enum GCD {}

    /// Intent names for Swift Concurrency (`Task`, `await`, actors).
    ///
    /// A task is not a thread. `await` suspends the task and **frees the
    /// thread**. Cancellation is a flag you must check. See <doc:ModernModel>.
    public enum Modern {}
}
