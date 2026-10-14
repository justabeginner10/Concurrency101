/// A global name: a value fixed at compile time, or one that belongs to a
/// particular run (the main queue, the `log` object).
enum GlobalEntry {
    case value(Value)
    case computed((Machine) throws -> Value)

    var staticValue: Value? {
        if case .value(let v) = self { return v }
        return nil
    }
}

/// Names visible everywhere: built-ins, then the prelude, then the
/// learner's own types. `implicitMembers` answers `.main`, `.seconds(…)`,
/// `.userInitiated` and friends.
final class GlobalTable {
    var entries: [String: GlobalEntry] = [:]
    var implicitMembers: [String: GlobalEntry] = [:]
    var userTypeNames: Set<String> = []
}
