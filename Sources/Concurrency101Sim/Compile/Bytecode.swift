/// Instructions for the stack machine. Each fiber executes one instruction
/// per simulated tick, so a `+=` split across several instructions can be
/// interleaved with another thread's `+=`, the same way it can in real code.
enum Op {
    case constant(Value)
    case pop
    case dup
    case loadLocal(Int)
    case loadUpvalue(Int)
    /// Pops a value into a fresh box (a new variable for each loop iteration).
    case declareLocal(Int, String)
    /// Creates an empty box ahead of time so hoisted functions can capture it.
    case boxLocal(Int, String)
    /// Pops a value into an existing box.
    case setLocal(Int)
    case addressLocal(Int)
    case addressUpvalue(Int)
    case addressMember(String)
    /// Pops a value into `self.<name>` while an instance is being built.
    case initField(String)
    case loadRef(rmw: Bool)
    case storeRef(rmw: Bool)
    case loadGlobal(String)
    case loadStatic(TypeObject, String)
    case getMember(String, awaited: Bool)
    case optionalGetMember(String, awaited: Bool)
    case tupleIndex(Int)
    case subscriptGet
    case call(argc: Int, labels: [String?], trailingStart: Int, awaited: Bool)
    case makeClosure(FunctionProto)
    case makeTuple(Int)
    case makeArray(Int)
    case binary(String)
    case prefix(String)
    case forceUnwrap
    case isType(String)
    case castOptional(String)
    case interpolate(Int)
    case implicitMember(String)
    case matchPattern
    case jump(Int)
    case jumpIfFalse(Int)
    case jumpIfTrue(Int)
    /// Pops and jumps when the top is nil; otherwise leaves it.
    case jumpIfNil(Int)
    case jumpIfNotMissing(slot: Int, target: Int)
    case ret
    case pushHandler(Int)
    case popHandler
    case throwTop
    case matchError(String)
    case registerDefer
    case makeIterator
    case asyncLetStart(Int, String)
    case awaitAsyncLet(String)
    case crash(String)
}

struct ParamInfo {
    var label: String?
    var name: String
    var hasDefault: Bool
    var isInout: Bool
}

/// Where a frame runs relative to its caller.
enum IsolationRule: Equatable {
    /// Runs on whatever executor called it.
    case inherit
    /// `@MainActor`: hops to the main actor.
    case main
    /// An actor method: hops to that actor.
    case actorSelf
    /// A nonisolated `async` function (SE-0338): hops to the shared pool.
    case pool
    /// An async closure that hops to the isolation it was formed in.
    case closureLexical
}

/// How a closure decides its static isolation when it is created.
enum LexicalRule: Equatable {
    case main
    case nonisolated
    case enclosing
    case actorSelf
}

enum UpvalueSource {
    case local(Int)
    case upvalue(Int)
}

final class FunctionProto {
    let name: String
    var params: [ParamInfo] = []
    var paramSlots: [Int] = []
    var code: [Op] = []
    var lines: [Int] = []
    var localCount = 0
    var upvalues: [UpvalueSource] = []
    var isAsync = false
    var throwsFlag = false
    var isolationRule: IsolationRule = .inherit
    var lexicalRule: LexicalRule = .enclosing
    /// Slot 0 holds `self`.
    var hasSelf = false
    var isClosure = false
    var isPrelude: Bool
    var isInit = false
    var line: Int

    init(name: String, isPrelude: Bool, line: Int) {
        self.name = name
        self.isPrelude = isPrelude
        self.line = line
    }

    func emit(_ op: Op, line: Int) -> Int {
        code.append(op)
        lines.append(line)
        return code.count - 1
    }

    func patch(_ index: Int, to target: Int) {
        switch code[index] {
        case .jump: code[index] = .jump(target)
        case .jumpIfFalse: code[index] = .jumpIfFalse(target)
        case .jumpIfTrue: code[index] = .jumpIfTrue(target)
        case .jumpIfNil: code[index] = .jumpIfNil(target)
        case .jumpIfNotMissing(let slot, _): code[index] = .jumpIfNotMissing(slot: slot, target: target)
        case .pushHandler: code[index] = .pushHandler(target)
        default: break
        }
    }
}

/// A user, prelude or built-in type. Namespaces (`enum`) hold only static
/// members; classes and actors also make instances.
final class TypeObject {
    enum Kind {
        case namespace
        case classType
        case actorType
        case builtin
    }

    struct Field {
        var name: String
        var isLet: Bool
    }

    let name: String
    let kind: Kind
    weak var parent: TypeObject?
    var isMainActor = false

    var staticFuncs: [String: [Closure]] = [:]
    var staticStored: [String: (proto: FunctionProto, isLet: Bool)] = [:]
    var staticStorage: [String: Box] = [:]
    var staticComputed: [String: FunctionProto] = [:]
    var nestedTypes: [String: TypeObject] = [:]
    var cases: [String] = []

    var fields: [Field] = []
    var fieldInit: FunctionProto?
    var methods: [String: [FunctionProto]] = [:]
    var computed: [String: FunctionProto] = [:]
    var inits: [FunctionProto] = []
    /// Synthetic `await actor.field` readers.
    var fieldGetters: [String: FunctionProto] = [:]

    /// Built-in members, keyed by name.
    var nativeStatics: [String: NativeMember] = [:]
    var nativeInit: NativeFunction?

    init(name: String, kind: Kind, parent: TypeObject? = nil) {
        self.name = name
        self.kind = kind
        self.parent = parent
    }

    var fullName: String {
        if let parent { return parent.fullName + "." + name }
        return name
    }

    var isActor: Bool { kind == .actorType }

    func hasStaticMember(_ name: String) -> Bool {
        staticFuncs[name] != nil || staticStored[name] != nil || staticComputed[name] != nil
            || nestedTypes[name] != nil || cases.contains(name) || nativeStatics[name] != nil
    }

    func hasInstanceMember(_ name: String) -> Bool {
        fields.contains { $0.name == name } || methods[name] != nil || computed[name] != nil
    }

    /// Static value of a member when it can be known without running code
    /// (used by the compiler's `await` / `try` checks).
    func staticValue(_ name: String) -> Value? {
        if let fns = staticFuncs[name] { return fns.count == 1 ? .closure(fns[0]) : .overloads(fns) }
        if let t = nestedTypes[name] { return .type(t) }
        if case .function(let f)? = nativeStatics[name] { return .native(f) }
        return nil
    }
}

enum NativeMember {
    case function(NativeFunction)
    case property((Machine) throws -> Value)
}
