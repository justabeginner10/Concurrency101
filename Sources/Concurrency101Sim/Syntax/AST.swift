/// The subset of Swift the sandbox understands. Types are parsed and kept
/// as text; the simulator is dynamically typed underneath.

struct Argument {
    var label: String?
    var value: Expr
    var isTrailingClosure = false
}

enum InterpolationPart {
    case text(String)
    case expr(Expr)
}

enum TryKind {
    case plain
    case optional
    case forced
}

final class ClosureExpr {
    var params: [Param]
    var attributes: [String]
    var body: [Stmt]
    var isAsync: Bool
    var throwsFlag: Bool
    var loc: SourceLocation
    /// Highest `$n` used directly in the body, or -1.
    var maxDollar: Int

    init(params: [Param], attributes: [String], body: [Stmt], isAsync: Bool, throwsFlag: Bool, loc: SourceLocation, maxDollar: Int) {
        self.params = params
        self.attributes = attributes
        self.body = body
        self.isAsync = isAsync
        self.throwsFlag = throwsFlag
        self.loc = loc
        self.maxDollar = maxDollar
    }
}

indirect enum ExprKind {
    case int(Int)
    case double(Double)
    case string([InterpolationPart])
    case bool(Bool)
    case nilLiteral
    case identifier(String)
    case dollar(Int)
    case selfRef
    case member(Expr, String)
    case optionalMember(Expr, String)
    case implicitMember(String)
    case tupleIndex(Expr, Int)
    case call(Expr, [Argument])
    case subscriptIndex(Expr, Expr)
    case closure(ClosureExpr)
    case binary(String, Expr, Expr)
    case prefix(String, Expr)
    case forceUnwrap(Expr)
    case ternary(Expr, Expr, Expr)
    case tuple([Expr])
    case array([Expr])
    case awaitExpr(Expr)
    case tryExpr(Expr, TryKind)
    case inoutRef(Expr)
    case isType(Expr, String)
    case cast(Expr, String, TryKind?)
}

struct Expr {
    var kind: ExprKind
    var loc: SourceLocation
}

struct Param {
    var label: String?
    var name: String
    var defaultValue: Expr?
    var isInout: Bool
    var typeText: String?
}

enum Pattern {
    case name(String)
    case wildcard
    case tuple([Pattern])
}

enum Condition {
    case expr(Expr)
    case optionalBinding(String, Expr)
}

enum CatchPattern {
    case any
    case isType(String)
    case bind(String, String?)
}

struct CatchClause {
    var pattern: CatchPattern
    var body: [Stmt]
    var loc: SourceLocation
}

struct SwitchCase {
    /// Empty means `default`.
    var patterns: [Expr]
    var bindName: String?
    var body: [Stmt]
    var loc: SourceLocation
}

final class FuncDecl {
    var name: String
    var params: [Param]
    var isAsync: Bool
    var throwsFlag: Bool
    var isStatic: Bool
    var isMainActor: Bool
    var isNonisolated: Bool
    var isInit: Bool
    var body: [Stmt]
    var loc: SourceLocation

    init(name: String, params: [Param], isAsync: Bool, throwsFlag: Bool, isStatic: Bool, isMainActor: Bool, isNonisolated: Bool, isInit: Bool, body: [Stmt], loc: SourceLocation) {
        self.name = name
        self.params = params
        self.isAsync = isAsync
        self.throwsFlag = throwsFlag
        self.isStatic = isStatic
        self.isMainActor = isMainActor
        self.isNonisolated = isNonisolated
        self.isInit = isInit
        self.body = body
        self.loc = loc
    }
}

struct StoredProperty {
    var name: String
    var isLet: Bool
    var isStatic: Bool
    var initializer: Expr?
    var loc: SourceLocation
}

struct ComputedProperty {
    var name: String
    var isStatic: Bool
    var isMainActor: Bool
    var body: [Stmt]
    var loc: SourceLocation
}

enum TypeKind: String {
    case namespace = "enum"
    case classType = "class"
    case actorType = "actor"
}

final class TypeDecl {
    var kind: TypeKind
    var name: String
    var stored: [StoredProperty] = []
    var computed: [ComputedProperty] = []
    var funcs: [FuncDecl] = []
    var nested: [TypeDecl] = []
    var cases: [String] = []
    var isMainActor: Bool
    var loc: SourceLocation

    init(kind: TypeKind, name: String, isMainActor: Bool, loc: SourceLocation) {
        self.kind = kind
        self.name = name
        self.isMainActor = isMainActor
        self.loc = loc
    }
}

indirect enum StmtKind {
    case expr(Expr)
    case varDecl(isLet: Bool, Pattern, Expr?)
    case asyncLet(String, Expr)
    case assign(Expr, String, Expr)
    case ifStmt([Condition], [Stmt], [Stmt]?)
    case guardStmt([Condition], [Stmt])
    case whileStmt(Expr, [Stmt])
    case repeatWhile([Stmt], Expr)
    case forIn(Pattern, isAwait: Bool, Expr, Expr?, [Stmt])
    case returnStmt(Expr?)
    case breakStmt
    case continueStmt
    case throwStmt(Expr)
    case doCatch([Stmt], [CatchClause])
    case deferStmt([Stmt])
    case funcDecl(FuncDecl)
    case typeDecl(TypeDecl)
    case switchStmt(Expr, [SwitchCase])
}

struct Stmt {
    var kind: StmtKind
    var loc: SourceLocation
}
