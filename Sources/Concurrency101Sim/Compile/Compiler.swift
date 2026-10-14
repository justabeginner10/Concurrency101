/// A compile-time error or warning in the learner's code.
public struct SimDiagnostic: Hashable, Sendable {
    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public var line: Int
    public var column: Int
    public var message: String
    public var severity: Severity

    public init(line: Int, column: Int, message: String, severity: Severity = .error) {
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }
}

/// What kind of closure an API expects, which decides whether `await` and
/// `throw` are allowed inside and where a nested `Task { }` runs.
private enum ClosureSlot: Equatable {
    case inferred
    case sync(String)
    case gcd
    /// A `@Sendable () async` parameter: nonisolated, runs on the pool.
    case async
    /// An async body that runs where its caller runs (`withTaskGroup`).
    case asyncInherit
    case task
}

private struct Local {
    var slot: Int
    var isLet: Bool
    var isAsyncLet: Bool
    var funcMeta: (isAsync: Bool, throwsFlag: Bool)?
}

private final class LoopContext {
    var breakPatches: [Int] = []
    var continuePatches: [Int] = []
    var continueTarget: Int?
    let isSwitch: Bool

    init(isSwitch: Bool) {
        self.isSwitch = isSwitch
    }
}

private final class TypeContext {
    let type: TypeObject
    let decl: TypeDecl
    let parent: TypeContext?

    init(type: TypeObject, decl: TypeDecl, parent: TypeContext?) {
        self.type = type
        self.decl = decl
        self.parent = parent
    }
}

private enum ThrowContext {
    case allowed
    case inferred
    case denied(String)
}

private final class FunctionState {
    let proto: FunctionProto
    let parent: FunctionState?
    let typeContext: TypeContext?
    /// Instance method (or a closure inside one): bare names may mean `self.x`.
    let isInstance: Bool
    var scopes: [[String: Local]] = [[:]]
    var upvalueIndex: [String: Int] = [:]
    var upvalueLocals: [Local] = []
    let awaitDenied: String?
    let throwContext: ThrowContext
    var doCatchDepth = 0
    var awaitDepth = 0
    var tryDepth = 0
    var loops: [LoopContext] = []
    let isMain: Bool

    init(proto: FunctionProto, parent: FunctionState?, typeContext: TypeContext?, isInstance: Bool, awaitDenied: String?, throwContext: ThrowContext, isMain: Bool = false) {
        self.proto = proto
        self.parent = parent
        self.typeContext = typeContext
        self.isInstance = isInstance
        self.awaitDenied = awaitDenied
        self.throwContext = throwContext
        self.isMain = isMain
    }

    func lookupLocal(_ name: String) -> Local? {
        for scope in scopes.reversed() {
            if let l = scope[name] { return l }
        }
        return nil
    }

    func allocate(_ name: String, isLet: Bool, isAsyncLet: Bool = false, funcMeta: (Bool, Bool)? = nil) -> Local {
        let local = Local(slot: proto.localCount, isLet: isLet, isAsyncLet: isAsyncLet, funcMeta: funcMeta)
        proto.localCount += 1
        if name != "_" {
            scopes[scopes.count - 1][name] = local
        }
        return local
    }

    func addUpvalue(_ name: String, _ source: UpvalueSource, _ local: Local) -> Int {
        if let i = upvalueIndex[name] { return i }
        proto.upvalues.append(source)
        upvalueLocals.append(local)
        let index = proto.upvalues.count - 1
        upvalueIndex[name] = index
        return index
    }
}

/// Compiles parsed statements into `FunctionProto`s and registers types
/// with the global table.
final class Compiler {
    let globals: GlobalTable
    let isPrelude: Bool
    private(set) var diagnostics: [SimDiagnostic] = []
    private var typeContexts: [ObjectIdentifier: TypeContext] = [:]
    private var pendingTypeBodies: [() -> Void] = []

    init(globals: GlobalTable, isPrelude: Bool) {
        self.globals = globals
        self.isPrelude = isPrelude
    }

    private func error(_ message: String, _ loc: SourceLocation) {
        diagnostics.append(SimDiagnostic(line: loc.line, column: loc.column, message: message))
    }

    // MARK: - Program

    /// Compiles a whole program. Returns the entry function (the code a
    /// button tap would run on the main thread).
    func compileProgram(_ stmts: [Stmt]) -> FunctionProto {
        // Phase A: every type, anywhere in the code, gets a TypeObject and
        // empty protos so code can refer to it before its body is compiled.
        var typeDecls: [TypeDecl] = []
        collectTypes(stmts, into: &typeDecls)
        for decl in typeDecls {
            declareType(decl, parent: nil)
        }

        let main = FunctionProto(name: isPrelude ? "prelude" : "main", isPrelude: isPrelude, line: 1)
        main.lexicalRule = .main
        let fs = FunctionState(
            proto: main, parent: nil, typeContext: nil, isInstance: false,
            awaitDenied: "this code runs like a button action on the main thread, which is synchronous. Wrap async work in Task { }.",
            throwContext: .denied("the code here can't throw. Handle the error with do/catch or try?."),
            isMain: true
        )

        if isPrelude {
            for stmt in stmts {
                if case .funcDecl(let fd) = stmt.kind {
                    let proto = makeFuncProto(fd, isMethod: false, type: nil)
                    compileFunctionBody(fd, proto: proto, parent: nil, typeContext: nil, isInstance: false)
                    globals.entries[fd.name] = .value(.closure(Closure(proto: proto, upvalues: [], selfValue: nil, isolation: .nonisolated)))
                }
            }
        } else {
            hoistTopLevel(stmts, fs)
            compileBlockBody(stmts, fs, skipHoisted: true)
        }
        _ = main.emit(.constant(.void), line: lastLine(stmts))
        _ = main.emit(.ret, line: lastLine(stmts))

        // Phase B: type bodies.
        while !pendingTypeBodies.isEmpty {
            let work = pendingTypeBodies
            pendingTypeBodies.removeAll()
            work.forEach { $0() }
        }
        return main
    }

    private func lastLine(_ stmts: [Stmt]) -> Int {
        stmts.last?.loc.line ?? 1
    }

    /// Top-level `let`/`var` get boxes up front so top-level functions
    /// (declared anywhere) can capture them.
    private func hoistTopLevel(_ stmts: [Stmt], _ fs: FunctionState) {
        var seen: [String: SourceLocation] = [:]
        func claim(_ name: String, _ loc: SourceLocation) -> Bool {
            if name == "_" { return true }
            if seen[name] != nil {
                error("invalid redeclaration of '\(name)'", loc)
                return false
            }
            seen[name] = loc
            return true
        }
        func names(_ p: Pattern) -> [String] {
            switch p {
            case .name(let n): return [n]
            case .wildcard: return []
            case .tuple(let items): return items.flatMap(names)
            }
        }
        var funcs: [(FuncDecl, Local)] = []
        for stmt in stmts {
            switch stmt.kind {
            case .varDecl(let isLet, let pattern, _):
                for n in names(pattern) where claim(n, stmt.loc) {
                    let l = fs.allocate(n, isLet: isLet)
                    _ = fs.proto.emit(.boxLocal(l.slot, n), line: stmt.loc.line)
                }
            case .asyncLet(let n, _):
                error("async let needs an async context. Put it inside Task { }.", stmt.loc)
                _ = claim(n, stmt.loc)
            case .funcDecl(let fd):
                if claim(fd.name, fd.loc) {
                    let l = fs.allocate(fd.name, isLet: true, funcMeta: (fd.isAsync, fd.throwsFlag))
                    _ = fs.proto.emit(.boxLocal(l.slot, fd.name), line: fd.loc.line)
                    funcs.append((fd, l))
                }
            default:
                break
            }
        }
        emitHoistedFuncs(funcs, fs)
    }

    private func emitHoistedFuncs(_ funcs: [(FuncDecl, Local)], _ fs: FunctionState) {
        for (fd, local) in funcs {
            let proto = makeFuncProto(fd, isMethod: false, type: nil)
            compileFunctionBody(fd, proto: proto, parent: fs, typeContext: fs.typeContext, isInstance: false)
            _ = fs.proto.emit(.makeClosure(proto), line: fd.loc.line)
            _ = fs.proto.emit(.setLocal(local.slot), line: fd.loc.line)
        }
    }

    // MARK: - Types

    private func collectTypes(_ stmts: [Stmt], into out: inout [TypeDecl]) {
        for stmt in stmts {
            switch stmt.kind {
            case .typeDecl(let t): out.append(t)
            default: break
            }
            forEachNestedBlock(stmt) { collectTypes($0, into: &out) }
        }
    }

    private func forEachNestedBlock(_ stmt: Stmt, _ body: ([Stmt]) -> Void) {
        func visitExpr(_ e: Expr) {
            walkClosures(e) { body($0.body) }
        }
        switch stmt.kind {
        case .expr(let e): visitExpr(e)
        case .varDecl(_, _, let e): if let e { visitExpr(e) }
        case .asyncLet(_, let e): visitExpr(e)
        case .assign(let a, _, let b): visitExpr(a); visitExpr(b)
        case .ifStmt(_, let a, let b): body(a); if let b { body(b) }
        case .guardStmt(_, let b): body(b)
        case .whileStmt(_, let b), .repeatWhile(let b, _): body(b)
        case .forIn(_, _, _, _, let b): body(b)
        case .returnStmt(let e): if let e { visitExpr(e) }
        case .throwStmt(let e): visitExpr(e)
        case .doCatch(let b, let cs): body(b); cs.forEach { body($0.body) }
        case .deferStmt(let b): body(b)
        case .funcDecl(let fd): body(fd.body)
        case .switchStmt(_, let cs): cs.forEach { body($0.body) }
        case .typeDecl, .breakStmt, .continueStmt: break
        }
    }

    private func walkClosures(_ e: Expr, _ visit: (ClosureExpr) -> Void) {
        switch e.kind {
        case .closure(let c): visit(c)
        case .member(let b, _), .optionalMember(let b, _), .tupleIndex(let b, _), .forceUnwrap(let b),
             .awaitExpr(let b), .tryExpr(let b, _), .inoutRef(let b), .isType(let b, _), .cast(let b, _, _), .prefix(_, let b):
            walkClosures(b, visit)
        case .call(let callee, let args):
            walkClosures(callee, visit)
            args.forEach { walkClosures($0.value, visit) }
        case .subscriptIndex(let a, let b), .binary(_, let a, let b):
            walkClosures(a, visit); walkClosures(b, visit)
        case .ternary(let a, let b, let c):
            walkClosures(a, visit); walkClosures(b, visit); walkClosures(c, visit)
        case .tuple(let items), .array(let items):
            items.forEach { walkClosures($0, visit) }
        case .string(let parts):
            for case .expr(let x) in parts { walkClosures(x, visit) }
        default: break
        }
    }

    private func declareType(_ decl: TypeDecl, parent: TypeContext?) {
        let kind: TypeObject.Kind
        switch decl.kind {
        case .namespace: kind = .namespace
        case .classType: kind = .classType
        case .actorType: kind = .actorType
        }
        let type = TypeObject(name: decl.name, kind: kind, parent: parent?.type)
        type.isMainActor = decl.isMainActor
        type.cases = decl.cases
        let ctx = TypeContext(type: type, decl: decl, parent: parent)
        typeContexts[ObjectIdentifier(type)] = ctx

        if let parent {
            parent.type.nestedTypes[decl.name] = type
        } else {
            if globals.entries[decl.name] != nil {
                error("'\(decl.name)' is already defined", decl.loc)
            }
            globals.entries[decl.name] = .value(.type(type))
            if !isPrelude { globals.userTypeNames.insert(decl.name) }
        }
        for c in decl.cases {
            globals.implicitMembers[c] = .value(.enumCase(decl.name, c))
        }

        // Protos first, bodies later.
        var instanceFuncs: [(FuncDecl, FunctionProto)] = []
        for fd in decl.funcs {
            let proto = makeFuncProto(fd, isMethod: !fd.isStatic, type: type)
            if fd.isInit {
                type.inits.append(proto)
            } else if fd.isStatic {
                let closure = Closure(proto: proto, upvalues: [], selfValue: nil, isolation: fd.isMainActor ? .main : .nonisolated)
                type.staticFuncs[fd.name, default: []].append(closure)
            } else {
                type.methods[fd.name, default: []].append(proto)
            }
            instanceFuncs.append((fd, proto))
        }
        var staticStored: [(StoredProperty, FunctionProto)] = []
        for prop in decl.stored {
            if prop.isStatic {
                let proto = FunctionProto(name: "\(decl.name).\(prop.name)", isPrelude: isPrelude, line: prop.loc.line)
                proto.lexicalRule = .nonisolated
                type.staticStored[prop.name] = (proto, prop.isLet)
                staticStored.append((prop, proto))
            } else {
                type.fields.append(TypeObject.Field(name: prop.name, isLet: prop.isLet))
            }
        }
        var computed: [(ComputedProperty, FunctionProto)] = []
        for prop in decl.computed {
            let proto = FunctionProto(name: "\(decl.name).\(prop.name)", isPrelude: isPrelude, line: prop.loc.line)
            proto.hasSelf = !prop.isStatic
            proto.isolationRule = prop.isMainActor ? .main : (type.isActor && !prop.isStatic ? .actorSelf : .inherit)
            proto.lexicalRule = prop.isMainActor ? .main : (type.isActor && !prop.isStatic ? .actorSelf : .nonisolated)
            if prop.isStatic { type.staticComputed[prop.name] = proto } else { type.computed[prop.name] = proto }
            computed.append((prop, proto))
        }
        if kind != .namespace {
            let fieldInit = FunctionProto(name: "\(decl.name).fields", isPrelude: isPrelude, line: decl.loc.line)
            fieldInit.hasSelf = true
            type.fieldInit = fieldInit
            if type.isActor {
                for field in type.fields {
                    let getter = FunctionProto(name: "\(decl.name).\(field.name)", isPrelude: isPrelude, line: decl.loc.line)
                    getter.hasSelf = true
                    getter.localCount = 1
                    getter.isolationRule = .actorSelf
                    _ = getter.emit(.loadLocal(0), line: decl.loc.line)
                    _ = getter.emit(.getMember(field.name, awaited: false), line: decl.loc.line)
                    _ = getter.emit(.ret, line: decl.loc.line)
                    type.fieldGetters[field.name] = getter
                }
            }
        }

        for nested in decl.nested {
            declareType(nested, parent: ctx)
        }

        pendingTypeBodies.append { [unowned self] in
            for (fd, proto) in instanceFuncs {
                self.compileFunctionBody(fd, proto: proto, parent: nil, typeContext: ctx, isInstance: !fd.isStatic)
            }
            for (prop, proto) in staticStored {
                let fs = FunctionState(proto: proto, parent: nil, typeContext: ctx, isInstance: false, awaitDenied: "a stored property's initial value can't 'await'", throwContext: .denied("a stored property's initial value can't throw"))
                if let initializer = prop.initializer {
                    self.compileExpr(initializer, fs)
                } else {
                    self.error("static property '\(prop.name)' needs an initial value", prop.loc)
                    _ = proto.emit(.constant(.nilValue), line: prop.loc.line)
                }
                _ = proto.emit(.ret, line: prop.loc.line)
            }
            for (prop, proto) in computed {
                let fs = FunctionState(proto: proto, parent: nil, typeContext: ctx, isInstance: !prop.isStatic, awaitDenied: "a computed property can't 'await' in the sandbox", throwContext: .denied("a computed property can't throw in the sandbox"))
                if !prop.isStatic { _ = fs.allocate("self", isLet: true) }
                self.compileBodyWithImplicitReturn(prop.body, fs, line: prop.loc.line)
            }
            if let fieldInit = type.fieldInit {
                let fs = FunctionState(proto: fieldInit, parent: nil, typeContext: ctx, isInstance: false, awaitDenied: "a stored property's initial value can't 'await'", throwContext: .denied("a stored property's initial value can't throw"))
                _ = fs.allocate("self", isLet: true)
                for prop in decl.stored where !prop.isStatic {
                    if let initializer = prop.initializer {
                        self.compileExpr(initializer, fs)
                        _ = fieldInit.emit(.initField(prop.name), line: prop.loc.line)
                    }
                }
                _ = fieldInit.emit(.constant(.void), line: decl.loc.line)
                _ = fieldInit.emit(.ret, line: decl.loc.line)
            }
        }
    }

    private func makeFuncProto(_ fd: FuncDecl, isMethod: Bool, type: TypeObject?) -> FunctionProto {
        let qualified = type.map { "\($0.name).\(fd.name)" } ?? fd.name
        let proto = FunctionProto(name: qualified, isPrelude: isPrelude, line: fd.loc.line)
        proto.isAsync = fd.isAsync
        proto.throwsFlag = fd.throwsFlag
        proto.hasSelf = isMethod
        proto.isInit = fd.isInit
        proto.params = fd.params.map { ParamInfo(label: $0.label, name: $0.name, hasDefault: $0.defaultValue != nil, isInout: $0.isInout) }
        let isActorMethod = isMethod && (type?.isActor ?? false) && !fd.isNonisolated && !fd.isInit
        if fd.isMainActor || (type?.isMainActor ?? false && !fd.isNonisolated) {
            proto.isolationRule = .main
            proto.lexicalRule = .main
        } else if isActorMethod {
            proto.isolationRule = .actorSelf
            proto.lexicalRule = .actorSelf
        } else if fd.isAsync && !isPrelude && !fd.isInit {
            proto.isolationRule = .pool
            proto.lexicalRule = .nonisolated
        } else {
            proto.isolationRule = .inherit
            proto.lexicalRule = .nonisolated
        }
        return proto
    }

    private func compileFunctionBody(_ fd: FuncDecl, proto: FunctionProto, parent: FunctionState?, typeContext: TypeContext?, isInstance: Bool) {
        let awaitDenied: String? = fd.isAsync ? nil : "'\(fd.name)' isn't async, so it can't 'await'. Mark it 'async'."
        let throwContext: ThrowContext = fd.throwsFlag ? .allowed : .denied("'\(fd.name)' isn't marked 'throws'. Handle the error with do/catch or try?.")
        let fs = FunctionState(proto: proto, parent: parent, typeContext: typeContext, isInstance: isInstance || (parent?.isInstance ?? false), awaitDenied: awaitDenied, throwContext: throwContext)
        if proto.hasSelf {
            _ = fs.allocate("self", isLet: true)
        }
        for (i, param) in fd.params.enumerated() {
            let local = fs.allocate(param.name, isLet: !param.isInout)
            proto.paramSlots.append(local.slot)
            if let def = param.defaultValue {
                let jump = proto.emit(.jumpIfNotMissing(slot: local.slot, target: -1), line: fd.loc.line)
                compileExpr(def, fs)
                _ = proto.emit(.setLocal(local.slot), line: fd.loc.line)
                proto.patch(jump, to: proto.code.count)
            }
            _ = i
        }
        if fd.isInit {
            compileBlockBody(fd.body, fs)
            _ = proto.emit(.constant(.void), line: fd.loc.line)
            _ = proto.emit(.ret, line: fd.loc.line)
        } else {
            compileBodyWithImplicitReturn(fd.body, fs, line: fd.loc.line)
        }
    }

    /// A body that is a single expression returns its value, as in Swift.
    private func compileBodyWithImplicitReturn(_ body: [Stmt], _ fs: FunctionState, line: Int) {
        if body.count == 1, case .expr(let e) = body[0].kind {
            compileExpr(e, fs)
            _ = fs.proto.emit(.ret, line: body[0].loc.line)
            return
        }
        compileBlockBody(body, fs)
        let end = body.last?.loc.line ?? line
        _ = fs.proto.emit(.constant(.void), line: end)
        _ = fs.proto.emit(.ret, line: end)
    }

    // MARK: - Statements

    private func compileBlock(_ stmts: [Stmt], _ fs: FunctionState) {
        fs.scopes.append([:])
        compileBlockBody(stmts, fs)
        fs.scopes.removeLast()
    }

    private func compileBlockBody(_ stmts: [Stmt], _ fs: FunctionState, skipHoisted: Bool = false) {
        if !skipHoisted {
            // Local functions may call each other, so give them boxes first.
            var funcs: [(FuncDecl, Local)] = []
            for stmt in stmts {
                if case .funcDecl(let fd) = stmt.kind {
                    let l = fs.allocate(fd.name, isLet: true, funcMeta: (fd.isAsync, fd.throwsFlag))
                    _ = fs.proto.emit(.boxLocal(l.slot, fd.name), line: fd.loc.line)
                    funcs.append((fd, l))
                }
            }
            emitHoistedFuncs(funcs, fs)
        }
        for stmt in stmts {
            compileStmt(stmt, fs)
        }
    }

    private func compileStmt(_ stmt: Stmt, _ fs: FunctionState) {
        let line = stmt.loc.line
        let proto = fs.proto
        switch stmt.kind {
        case .expr(let e):
            compileExpr(e, fs)
            _ = proto.emit(.pop, line: line)

        case .varDecl(let isLet, let pattern, let initializer):
            if let initializer {
                compileExpr(initializer, fs)
            } else {
                _ = proto.emit(.constant(.uninitialized), line: line)
            }
            bind(pattern, isLet: isLet, fs, line: line, topLevel: fs.isMain && fs.scopes.count == 1)

        case .asyncLet(let name, let value):
            if fs.awaitDenied != nil {
                if !(fs.isMain && fs.scopes.count == 1) {
                    error("async let needs an async context (a Task, or an async function)", stmt.loc)
                }
                return
            }
            // The initializer runs in its own child task and is implicitly
            // awaited (and tried) there; the reader writes `await` later.
            let implicit = Expr(kind: .tryExpr(Expr(kind: .awaitExpr(value), loc: value.loc), .plain), loc: value.loc)
            let closure = ClosureExpr(params: [], attributes: [], body: [Stmt(kind: .expr(implicit), loc: value.loc)], isAsync: true, throwsFlag: false, loc: value.loc, maxDollar: -1)
            compileClosure(closure, fs, slot: .task, lexical: .nonisolated)
            let local = fs.allocate(name, isLet: true, isAsyncLet: true)
            _ = proto.emit(.asyncLetStart(local.slot, name), line: line)

        case .assign(let target, let op, let value):
            compileAssign(target, op, value, fs, loc: stmt.loc)

        case .ifStmt(let conds, let then, let elseBody):
            fs.scopes.append([:])
            var elsePatches: [Int] = []
            compileConditions(conds, fs, line: line, failPatches: &elsePatches)
            compileBlock(then, fs)
            fs.scopes.removeLast()
            let endJump = proto.emit(.jump(-1), line: line)
            let elseStart = proto.code.count
            elsePatches.forEach { proto.patch($0, to: elseStart) }
            if let elseBody {
                compileBlock(elseBody, fs)
            }
            proto.patch(endJump, to: proto.code.count)

        case .guardStmt(let conds, let elseBody):
            var failPatches: [Int] = []
            compileConditions(conds, fs, line: line, failPatches: &failPatches)
            let okJump = proto.emit(.jump(-1), line: line)
            let elseStart = proto.code.count
            failPatches.forEach { proto.patch($0, to: elseStart) }
            compileBlock(elseBody, fs)
            if !exits(elseBody) {
                error("the 'else' of a guard must leave the scope (return, throw, break or continue)", stmt.loc)
            }
            proto.patch(okJump, to: proto.code.count)

        case .whileStmt(let cond, let body):
            let top = proto.code.count
            compileExpr(cond, fs)
            let exitJump = proto.emit(.jumpIfFalse(-1), line: line)
            let loop = LoopContext(isSwitch: false)
            loop.continueTarget = top
            fs.loops.append(loop)
            compileBlock(body, fs)
            fs.loops.removeLast()
            _ = proto.emit(.jump(top), line: line)
            let end = proto.code.count
            proto.patch(exitJump, to: end)
            loop.breakPatches.forEach { proto.patch($0, to: end) }

        case .repeatWhile(let body, let cond):
            let top = proto.code.count
            let loop = LoopContext(isSwitch: false)
            fs.loops.append(loop)
            compileBlock(body, fs)
            fs.loops.removeLast()
            let condStart = proto.code.count
            loop.continuePatches.forEach { proto.patch($0, to: condStart) }
            compileExpr(cond, fs)
            let exitJump = proto.emit(.jumpIfFalse(-1), line: line)
            _ = proto.emit(.jump(top), line: line)
            let end = proto.code.count
            proto.patch(exitJump, to: end)
            loop.breakPatches.forEach { proto.patch($0, to: end) }

        case .forIn(let pattern, let isAwait, let sequence, let whereClause, let body):
            if isAwait, let denied = fs.awaitDenied {
                error("'for await' can't be used here: \(denied)", stmt.loc)
            }
            compileExpr(sequence, fs)
            _ = proto.emit(.makeIterator, line: line)
            let top = proto.code.count
            _ = proto.emit(.dup, line: line)
            _ = proto.emit(.getMember("next", awaited: isAwait), line: line)
            _ = proto.emit(.call(argc: 0, labels: [], trailingStart: 0, awaited: isAwait), line: line)
            let exitJump = proto.emit(.jumpIfNil(-1), line: line)
            fs.scopes.append([:])
            bind(pattern, isLet: true, fs, line: line, topLevel: false)
            if let whereClause {
                compileExpr(whereClause, fs)
                _ = proto.emit(.jumpIfFalse(top), line: line)
            }
            let loop = LoopContext(isSwitch: false)
            loop.continueTarget = top
            fs.loops.append(loop)
            compileBlock(body, fs)
            fs.loops.removeLast()
            fs.scopes.removeLast()
            _ = proto.emit(.jump(top), line: line)
            let end = proto.code.count
            proto.patch(exitJump, to: end)
            loop.breakPatches.forEach { proto.patch($0, to: end) }
            _ = proto.emit(.pop, line: line)

        case .returnStmt(let value):
            if let value {
                compileExpr(value, fs)
            } else {
                _ = proto.emit(.constant(.void), line: line)
            }
            _ = proto.emit(.ret, line: line)

        case .breakStmt:
            guard let loop = fs.loops.last else {
                error("'break' is only allowed inside a loop or switch", stmt.loc)
                return
            }
            loop.breakPatches.append(proto.emit(.jump(-1), line: line))

        case .continueStmt:
            guard let loop = fs.loops.last(where: { !$0.isSwitch }) else {
                error("'continue' is only allowed inside a loop", stmt.loc)
                return
            }
            if let target = loop.continueTarget {
                _ = proto.emit(.jump(target), line: line)
            } else {
                loop.continuePatches.append(proto.emit(.jump(-1), line: line))
            }

        case .throwStmt(let value):
            checkThrowAllowed(fs, stmt.loc)
            compileExpr(value, fs)
            _ = proto.emit(.throwTop, line: line)

        case .doCatch(let body, let clauses):
            if clauses.isEmpty {
                compileBlock(body, fs)
                return
            }
            let handler = proto.emit(.pushHandler(-1), line: line)
            fs.doCatchDepth += 1
            compileBlock(body, fs)
            fs.doCatchDepth -= 1
            _ = proto.emit(.popHandler, line: line)
            var endPatches = [proto.emit(.jump(-1), line: line)]
            proto.patch(handler, to: proto.code.count)
            for clause in clauses {
                let cline = clause.loc.line
                fs.scopes.append([:])
                switch clause.pattern {
                case .any:
                    let l = fs.allocate("error", isLet: true)
                    _ = proto.emit(.declareLocal(l.slot, "error"), line: cline)
                    compileBlock(clause.body, fs)
                    endPatches.append(proto.emit(.jump(-1), line: cline))
                case .isType(let typeName):
                    _ = proto.emit(.dup, line: cline)
                    _ = proto.emit(.matchError(typeName), line: cline)
                    let next = proto.emit(.jumpIfFalse(-1), line: cline)
                    let l = fs.allocate("error", isLet: true)
                    _ = proto.emit(.declareLocal(l.slot, "error"), line: cline)
                    compileBlock(clause.body, fs)
                    endPatches.append(proto.emit(.jump(-1), line: cline))
                    proto.patch(next, to: proto.code.count)
                case .bind(let name, let typeName):
                    var next: Int?
                    if let typeName {
                        _ = proto.emit(.dup, line: cline)
                        _ = proto.emit(.matchError(typeName), line: cline)
                        next = proto.emit(.jumpIfFalse(-1), line: cline)
                    }
                    let l = fs.allocate(name, isLet: true)
                    _ = proto.emit(.declareLocal(l.slot, name), line: cline)
                    compileBlock(clause.body, fs)
                    endPatches.append(proto.emit(.jump(-1), line: cline))
                    if let next { proto.patch(next, to: proto.code.count) }
                }
                fs.scopes.removeLast()
            }
            _ = proto.emit(.throwTop, line: line)
            let end = proto.code.count
            endPatches.forEach { proto.patch($0, to: end) }

        case .deferStmt(let body):
            if fs.scopes.count != 1 || fs.isMain {
                error("the sandbox supports 'defer' only at the top of a function or closure body", stmt.loc)
                return
            }
            let closure = ClosureExpr(params: [], attributes: [], body: body, isAsync: false, throwsFlag: false, loc: stmt.loc, maxDollar: -1)
            compileClosure(closure, fs, slot: .sync("defer"), lexical: .enclosing)
            _ = proto.emit(.registerDefer, line: line)

        case .funcDecl:
            break

        case .typeDecl:
            break

        case .switchStmt(let subject, let cases):
            compileExpr(subject, fs)
            fs.scopes.append([:])
            let tmp = fs.allocate("$switch", isLet: true)
            _ = proto.emit(.declareLocal(tmp.slot, "switch"), line: line)
            let loop = LoopContext(isSwitch: true)
            fs.loops.append(loop)
            var endPatches: [Int] = []
            for c in cases {
                let cline = c.loc.line
                fs.scopes.append([:])
                var next: Int?
                if let bindName = c.bindName {
                    _ = proto.emit(.loadLocal(tmp.slot), line: cline)
                    let l = fs.allocate(bindName, isLet: true)
                    _ = proto.emit(.declareLocal(l.slot, bindName), line: cline)
                } else if !c.patterns.isEmpty {
                    var bodyPatches: [Int] = []
                    for p in c.patterns {
                        if case .identifier("_") = p.kind {
                            bodyPatches.append(proto.emit(.jump(-1), line: cline))
                            continue
                        }
                        _ = proto.emit(.loadLocal(tmp.slot), line: cline)
                        compileExpr(p, fs)
                        _ = proto.emit(.matchPattern, line: cline)
                        bodyPatches.append(proto.emit(.jumpIfTrue(-1), line: cline))
                    }
                    next = proto.emit(.jump(-1), line: cline)
                    bodyPatches.forEach { proto.patch($0, to: proto.code.count) }
                }
                compileBlockBody(c.body, fs)
                endPatches.append(proto.emit(.jump(-1), line: cline))
                if let next { proto.patch(next, to: proto.code.count) }
                fs.scopes.removeLast()
            }
            fs.loops.removeLast()
            fs.scopes.removeLast()
            let end = proto.code.count
            endPatches.forEach { proto.patch($0, to: end) }
            loop.breakPatches.forEach { proto.patch($0, to: end) }
        }
    }

    private func exits(_ body: [Stmt]) -> Bool {
        guard let last = body.last else { return false }
        switch last.kind {
        case .returnStmt, .throwStmt, .breakStmt, .continueStmt: return true
        case .expr(let e):
            if case .call(let callee, _) = e.kind, case .identifier(let name) = callee.kind {
                return name == "fatalError" || name == "preconditionFailure"
            }
            return false
        default: return false
        }
    }

    private func compileConditions(_ conds: [Condition], _ fs: FunctionState, line: Int, failPatches: inout [Int]) {
        for cond in conds {
            switch cond {
            case .expr(let e):
                compileExpr(e, fs)
                failPatches.append(fs.proto.emit(.jumpIfFalse(-1), line: line))
            case .optionalBinding(let name, let e):
                compileExpr(e, fs)
                failPatches.append(fs.proto.emit(.jumpIfNil(-1), line: line))
                let l = fs.allocate(name, isLet: true)
                _ = fs.proto.emit(.declareLocal(l.slot, name), line: line)
            }
        }
    }

    private func bind(_ pattern: Pattern, isLet: Bool, _ fs: FunctionState, line: Int, topLevel: Bool) {
        switch pattern {
        case .wildcard:
            _ = fs.proto.emit(.pop, line: line)
        case .name(let name):
            if topLevel, let existing = fs.scopes[0][name] {
                _ = fs.proto.emit(.setLocal(existing.slot), line: line)
            } else {
                let l = fs.allocate(name, isLet: isLet)
                _ = fs.proto.emit(.declareLocal(l.slot, name), line: line)
            }
        case .tuple(let items):
            for (i, item) in items.enumerated() {
                _ = fs.proto.emit(.dup, line: line)
                _ = fs.proto.emit(.tupleIndex(i), line: line)
                bind(item, isLet: isLet, fs, line: line, topLevel: topLevel)
            }
            _ = fs.proto.emit(.pop, line: line)
        }
    }

    private func compileAssign(_ target: Expr, _ op: String, _ value: Expr, _ fs: FunctionState, loc: SourceLocation) {
        let line = loc.line
        if case .identifier("_") = target.kind {
            compileExpr(value, fs)
            _ = fs.proto.emit(.pop, line: line)
            return
        }
        guard compileAddress(target, fs, forWrite: true) else { return }
        if op == "=" {
            compileExpr(value, fs)
            _ = fs.proto.emit(.storeRef(rmw: false), line: line)
        } else {
            _ = fs.proto.emit(.dup, line: line)
            _ = fs.proto.emit(.loadRef(rmw: true), line: line)
            compileExpr(value, fs)
            _ = fs.proto.emit(.binary(String(op.dropLast())), line: line)
            _ = fs.proto.emit(.storeRef(rmw: true), line: line)
        }
    }

    /// Pushes a reference to the variable or property `target` names.
    @discardableResult
    private func compileAddress(_ target: Expr, _ fs: FunctionState, forWrite: Bool) -> Bool {
        let line = target.loc.line
        switch target.kind {
        case .identifier, .dollar:
            var name = ""
            if case .identifier(let n) = target.kind { name = n }
            if case .dollar(let n) = target.kind { name = "$\(n)" }
            switch resolve(name, fs) {
            case .local(let l):
                if forWrite && l.isLet {
                    error("cannot assign to '\(name)': it is a 'let' constant", target.loc)
                }
                _ = fs.proto.emit(.addressLocal(l.slot), line: line)
                return true
            case .upvalue(let i, let l):
                if forWrite && l.isLet {
                    error("cannot assign to '\(name)': it is a 'let' constant", target.loc)
                }
                _ = fs.proto.emit(.addressUpvalue(i), line: line)
                return true
            case .selfMember:
                emitSelf(fs, target.loc)
                _ = fs.proto.emit(.addressMember(name), line: line)
                return true
            case .staticMember(let type, _):
                error("assigning to static property '\(type.name).\(name)' isn't supported in the sandbox yet", target.loc)
                return false
            default:
                error("cannot find '\(name)' in scope", target.loc)
                return false
            }
        case .member(let base, let name):
            compileExpr(base, fs)
            _ = fs.proto.emit(.addressMember(name), line: line)
            return true
        default:
            error("the sandbox can only assign to a variable or a property", target.loc)
            return false
        }
    }

    // MARK: - Name resolution

    private enum Resolved {
        case local(Local)
        case upvalue(Int, Local)
        case selfMember
        case staticMember(TypeObject, String)
        case global
        case unknown
    }

    private func resolve(_ name: String, _ fs: FunctionState) -> Resolved {
        if let l = fs.lookupLocal(name) { return .local(l) }
        if let i = resolveUpvalue(name, fs) { return .upvalue(i, fs.upvalueLocals[i]) }
        var ctx = fs.typeContext
        if fs.isInstance, let type = ctx?.type, type.hasInstanceMember(name) {
            return .selfMember
        }
        while let c = ctx {
            if c.type.hasStaticMember(name) { return .staticMember(c.type, name) }
            ctx = c.parent
        }
        if globals.entries[name] != nil { return .global }
        return .unknown
    }

    private func resolveUpvalue(_ name: String, _ fs: FunctionState) -> Int? {
        if let i = fs.upvalueIndex[name] { return i }
        guard let parent = fs.parent else { return nil }
        if let l = parent.lookupLocal(name) {
            return fs.addUpvalue(name, .local(l.slot), l)
        }
        if let i = resolveUpvalue(name, parent) {
            return fs.addUpvalue(name, .upvalue(i), parent.upvalueLocals[i])
        }
        return nil
    }

    private func emitSelf(_ fs: FunctionState, _ loc: SourceLocation) {
        switch resolve("self", fs) {
        case .local(let l): _ = fs.proto.emit(.loadLocal(l.slot), line: loc.line)
        case .upvalue(let i, _): _ = fs.proto.emit(.loadUpvalue(i), line: loc.line)
        default:
            error("'self' is only available inside a class or actor method", loc)
            _ = fs.proto.emit(.constant(.nilValue), line: loc.line)
        }
    }

    /// The function a call refers to, when it can be known without running
    /// anything. Used for `await` / `try` checks.
    private func staticMeta(_ callee: Expr, _ fs: FunctionState) -> (name: String, isAsync: Bool, throwsFlag: Bool)? {
        func meta(_ v: Value, _ name: String) -> (String, Bool, Bool)? {
            switch v {
            case .closure(let c): return (name, c.proto.isAsync, c.proto.throwsFlag)
            case .overloads(let cs):
                guard let f = cs.first, cs.allSatisfy({ $0.proto.isAsync == f.proto.isAsync && $0.proto.throwsFlag == f.proto.throwsFlag }) else { return nil }
                return (name, f.proto.isAsync, f.proto.throwsFlag)
            case .native(let n): return (name, n.isAsync, n.throwsFlag)
            default: return nil
            }
        }
        func value(_ e: Expr) -> Value? {
            switch e.kind {
            case .identifier(let name):
                switch resolve(name, fs) {
                case .staticMember(let t, let n): return t.staticValue(n)
                case .global: return globals.entries[name]?.staticValue
                default: return nil
                }
            case .member(let base, let name):
                if case .type(let t)? = value(base) { return t.staticValue(name) }
                return nil
            default:
                return nil
            }
        }
        switch callee.kind {
        case .identifier(let name):
            if case .local(let l) = resolve(name, fs), let m = l.funcMeta { return (name, m.isAsync, m.throwsFlag) }
            if case .upvalue(_, let l) = resolve(name, fs), let m = l.funcMeta { return (name, m.isAsync, m.throwsFlag) }
            if let v = value(callee) { return meta(v, name) }
        case .member(_, let name):
            if let v = value(callee) { return meta(v, name) }
        default:
            break
        }
        return nil
    }

    private func checkThrowAllowed(_ fs: FunctionState, _ loc: SourceLocation) {
        // Prelude helpers rethrow whatever their body throws (`MainActor.run`).
        if fs.doCatchDepth > 0 || isPrelude { return }
        if case .denied(let why) = fs.throwContext {
            error(why, loc)
        }
    }

    // MARK: - Expressions

    private func compileExpr(_ e: Expr, _ fs: FunctionState) {
        let line = e.loc.line
        let proto = fs.proto
        switch e.kind {
        case .int(let i):
            _ = proto.emit(.constant(.int(i)), line: line)
        case .double(let d):
            _ = proto.emit(.constant(.double(d)), line: line)
        case .bool(let b):
            _ = proto.emit(.constant(.bool(b)), line: line)
        case .nilLiteral:
            _ = proto.emit(.constant(.nilValue), line: line)
        case .string(let parts):
            if parts.count == 1, case .text(let s) = parts[0] {
                _ = proto.emit(.constant(.string(s)), line: line)
                return
            }
            for part in parts {
                switch part {
                case .text(let s): _ = proto.emit(.constant(.string(s)), line: line)
                case .expr(let x): compileExpr(x, fs)
                }
            }
            _ = proto.emit(.interpolate(parts.count), line: line)

        case .identifier(let name):
            compileIdentifier(name, e.loc, fs)
        case .dollar(let n):
            compileIdentifier("$\(n)", e.loc, fs)
        case .selfRef:
            emitSelf(fs, e.loc)

        case .member(let base, let name):
            compileExpr(base, fs)
            _ = proto.emit(.getMember(name, awaited: fs.awaitDepth > 0), line: line)
        case .optionalMember(let base, let name):
            compileExpr(base, fs)
            _ = proto.emit(.optionalGetMember(name, awaited: fs.awaitDepth > 0), line: line)
        case .implicitMember(let name):
            if globals.implicitMembers[name] == nil {
                error("unknown member '.\(name)'", e.loc)
            }
            _ = proto.emit(.implicitMember(name), line: line)
        case .tupleIndex(let base, let i):
            compileExpr(base, fs)
            _ = proto.emit(.tupleIndex(i), line: line)
        case .subscriptIndex(let base, let index):
            compileExpr(base, fs)
            compileExpr(index, fs)
            _ = proto.emit(.subscriptGet, line: line)

        case .call(let callee, let args):
            compileCall(callee, args, e.loc, fs)

        case .closure(let c):
            compileClosure(c, fs, slot: .inferred, lexical: .enclosing)

        case .binary(let op, let lhs, let rhs):
            switch op {
            case "&&":
                compileExpr(lhs, fs)
                let toFalse = proto.emit(.jumpIfFalse(-1), line: line)
                compileExpr(rhs, fs)
                let end = proto.emit(.jump(-1), line: line)
                proto.patch(toFalse, to: proto.code.count)
                _ = proto.emit(.constant(.bool(false)), line: line)
                proto.patch(end, to: proto.code.count)
            case "||":
                compileExpr(lhs, fs)
                let toTrue = proto.emit(.jumpIfTrue(-1), line: line)
                compileExpr(rhs, fs)
                let end = proto.emit(.jump(-1), line: line)
                proto.patch(toTrue, to: proto.code.count)
                _ = proto.emit(.constant(.bool(true)), line: line)
                proto.patch(end, to: proto.code.count)
            case "??":
                compileExpr(lhs, fs)
                let toRhs = proto.emit(.jumpIfNil(-1), line: line)
                let end = proto.emit(.jump(-1), line: line)
                proto.patch(toRhs, to: proto.code.count)
                compileExpr(rhs, fs)
                proto.patch(end, to: proto.code.count)
            default:
                compileExpr(lhs, fs)
                compileExpr(rhs, fs)
                _ = proto.emit(.binary(op), line: line)
            }
        case .prefix(let op, let operand):
            compileExpr(operand, fs)
            _ = proto.emit(.prefix(op), line: line)
        case .forceUnwrap(let inner):
            compileExpr(inner, fs)
            _ = proto.emit(.forceUnwrap, line: line)
        case .ternary(let cond, let a, let b):
            compileExpr(cond, fs)
            let toElse = proto.emit(.jumpIfFalse(-1), line: line)
            compileExpr(a, fs)
            let end = proto.emit(.jump(-1), line: line)
            proto.patch(toElse, to: proto.code.count)
            compileExpr(b, fs)
            proto.patch(end, to: proto.code.count)
        case .tuple(let items):
            if items.isEmpty {
                _ = proto.emit(.constant(.void), line: line)
                return
            }
            items.forEach { compileExpr($0, fs) }
            _ = proto.emit(.makeTuple(items.count), line: line)
        case .array(let items):
            items.forEach { compileExpr($0, fs) }
            _ = proto.emit(.makeArray(items.count), line: line)

        case .awaitExpr(let inner):
            if let denied = fs.awaitDenied {
                error(denied, e.loc)
            }
            fs.awaitDepth += 1
            compileExpr(inner, fs)
            fs.awaitDepth -= 1

        case .tryExpr(let inner, let kind):
            switch kind {
            case .plain:
                checkThrowAllowed(fs, e.loc)
                fs.tryDepth += 1
                compileExpr(inner, fs)
                fs.tryDepth -= 1
            case .optional, .forced:
                let handler = proto.emit(.pushHandler(-1), line: line)
                fs.tryDepth += 1
                fs.doCatchDepth += 1
                compileExpr(inner, fs)
                fs.doCatchDepth -= 1
                fs.tryDepth -= 1
                _ = proto.emit(.popHandler, line: line)
                let end = proto.emit(.jump(-1), line: line)
                proto.patch(handler, to: proto.code.count)
                if kind == .optional {
                    _ = proto.emit(.pop, line: line)
                    _ = proto.emit(.constant(.nilValue), line: line)
                } else {
                    _ = proto.emit(.crash("'try!' expression unexpectedly raised an error"), line: line)
                }
                proto.patch(end, to: proto.code.count)
            }

        case .inoutRef(let inner):
            compileAddress(inner, fs, forWrite: true)
        case .isType(let inner, let typeName):
            compileExpr(inner, fs)
            _ = proto.emit(.isType(typeName), line: line)
        case .cast(let inner, let typeName, let kind):
            compileExpr(inner, fs)
            if kind == .optional {
                _ = proto.emit(.castOptional(typeName), line: line)
            }
        }
    }

    private func compileIdentifier(_ name: String, _ loc: SourceLocation, _ fs: FunctionState) {
        let line = loc.line
        if name == "#function" {
            _ = fs.proto.emit(.constant(.string(fs.proto.name)), line: line)
            return
        }
        if name == "Self", let type = fs.typeContext?.type {
            _ = fs.proto.emit(.constant(.type(type)), line: line)
            return
        }
        switch resolve(name, fs) {
        case .local(let l):
            _ = fs.proto.emit(.loadLocal(l.slot), line: line)
            if l.isAsyncLet { emitAsyncLetRead(name, loc, fs) }
        case .upvalue(let i, let l):
            _ = fs.proto.emit(.loadUpvalue(i), line: line)
            if l.isAsyncLet { emitAsyncLetRead(name, loc, fs) }
        case .selfMember:
            emitSelf(fs, loc)
            _ = fs.proto.emit(.getMember(name, awaited: fs.awaitDepth > 0), line: line)
        case .staticMember(let type, let member):
            _ = fs.proto.emit(.loadStatic(type, member), line: line)
        case .global:
            _ = fs.proto.emit(.loadGlobal(name), line: line)
        case .unknown:
            if name.hasPrefix("$") {
                error("\(name) can only be used inside a closure", loc)
            } else {
                error("cannot find '\(name)' in scope", loc)
            }
            _ = fs.proto.emit(.constant(.void), line: line)
        }
    }

    private func emitAsyncLetRead(_ name: String, _ loc: SourceLocation, _ fs: FunctionState) {
        if fs.awaitDepth == 0 {
            error("reading async let '\(name)' needs 'await'", loc)
        }
        _ = fs.proto.emit(.awaitAsyncLet(name), line: loc.line)
    }

    private func pathComponents(_ e: Expr) -> [String]? {
        switch e.kind {
        case .identifier(let n): return [n]
        case .implicitMember(let n): return ["." + n]
        case .member(let base, let n):
            guard let p = pathComponents(base) else {
                if case .call = base.kind { return ["()", n] }
                return [n]
            }
            return p + [n]
        case .call(let callee, _):
            return pathComponents(callee).map { $0 + ["()"] }
        default:
            return nil
        }
    }

    /// Decides what kind of closure `callee` expects for `label`.
    private func classifySlot(_ callee: Expr, label: String?) -> (ClosureSlot, LexicalRule) {
        let path = (pathComponents(callee) ?? []).filter { $0 != "()" }
        let last = path.last ?? ""
        let joined = path.joined(separator: ".")
        let receiverIsMain = path.dropLast().last.map { $0 == "main" || $0 == ".main" } ?? false

        if joined == "Task" || joined == "Task.init" { return (.task, .enclosing) }
        if joined == "Task.detached" { return (.task, .nonisolated) }
        if last == "addTask" || last == "addTaskUnlessCancelled" { return (.task, .nonisolated) }
        if path.contains("GCD") {
            return (.gcd, last == "updateUI" ? .main : .nonisolated)
        }
        if path.contains("Modern") {
            switch last {
            case "waitForUI", "updateUI": return (.sync("\(last)"), .main)
            case "waitForCallback", "waitForThrowingCallback": return (.sync(last), .enclosing)
            default: return (.async, .nonisolated)
            }
        }
        if ["async", "asyncAfter", "sync", "notify", "concurrentPerform", "asyncAndWait"].contains(last) {
            return (.gcd, receiverIsMain ? .main : .nonisolated)
        }
        if path.first == "DispatchWorkItem" { return (.gcd, .nonisolated) }
        if joined == "MainActor.run" { return (.sync("MainActor.run"), .main) }
        if last == "modify" { return (.sync("modify"), .nonisolated) }
        if last == "readAwaitWrite" { return (.async, .nonisolated) }
        if ["withCheckedContinuation", "withCheckedThrowingContinuation", "withUnsafeContinuation", "withUnsafeThrowingContinuation"].contains(last) {
            return (.sync(last), .enclosing)
        }
        if ["withTaskGroup", "withThrowingTaskGroup", "withDiscardingTaskGroup", "withThrowingDiscardingTaskGroup", "withTaskCancellationHandler"].contains(last) {
            return (.asyncInherit, .enclosing)
        }
        return (.inferred, .enclosing)
    }

    private func compileCall(_ callee: Expr, _ args: [Argument], _ loc: SourceLocation, _ fs: FunctionState) {
        let line = loc.line
        if let meta = staticMeta(callee, fs) {
            if meta.isAsync && fs.awaitDepth == 0 && fs.awaitDenied == nil {
                error("'\(meta.name)' is async: mark the call with 'await'", loc)
            } else if meta.isAsync && fs.awaitDenied != nil && fs.awaitDepth == 0 {
                error("'\(meta.name)' is async and can't be called here: \(fs.awaitDenied!)", loc)
            }
            if meta.throwsFlag && fs.tryDepth == 0 {
                error("'\(meta.name)' can throw: mark the call with 'try' (or 'try?')", loc)
            }
        }
        let awaited = fs.awaitDepth > 0
        compileExpr(callee, fs)
        var labels: [String?] = []
        var trailingStart = args.count
        for (i, arg) in args.enumerated() {
            if arg.isTrailingClosure && trailingStart == args.count { trailingStart = i }
            labels.append(arg.label)
            switch arg.value.kind {
            case .closure(let c):
                let (slot, lexical) = classifySlot(callee, label: arg.label)
                compileClosure(c, fs, slot: slot, lexical: lexical)
            case .array(let items) where items.contains(where: { if case .closure = $0.kind { return true }; return false }):
                // `jobs: [ { … }, { … } ]` gets the same treatment as a
                // single closure argument.
                let (slot, lexical) = classifySlot(callee, label: arg.label)
                for item in items {
                    if case .closure(let c) = item.kind {
                        compileClosure(c, fs, slot: slot, lexical: lexical)
                    } else {
                        compileExpr(item, fs)
                    }
                }
                _ = fs.proto.emit(.makeArray(items.count), line: arg.value.loc.line)
            default:
                compileExpr(arg.value, fs)
            }
        }
        _ = fs.proto.emit(.call(argc: args.count, labels: labels, trailingStart: trailingStart, awaited: awaited), line: line)
    }

    private func containsAwait(_ stmts: [Stmt]) -> Bool {
        var found = false
        func expr(_ e: Expr) {
            if found { return }
            switch e.kind {
            case .awaitExpr: found = true
            case .closure: break
            case .member(let b, _), .optionalMember(let b, _), .tupleIndex(let b, _), .forceUnwrap(let b),
                 .tryExpr(let b, _), .inoutRef(let b), .isType(let b, _), .cast(let b, _, _), .prefix(_, let b):
                expr(b)
            case .call(let c, let args):
                expr(c)
                args.forEach { expr($0.value) }
            case .subscriptIndex(let a, let b), .binary(_, let a, let b):
                expr(a); expr(b)
            case .ternary(let a, let b, let c):
                expr(a); expr(b); expr(c)
            case .tuple(let items), .array(let items):
                items.forEach(expr)
            case .string(let parts):
                for case .expr(let x) in parts { expr(x) }
            default: break
            }
        }
        func stmt(_ s: Stmt) {
            if found { return }
            switch s.kind {
            case .expr(let e), .throwStmt(let e): expr(e)
            case .varDecl(_, _, let e): if let e { expr(e) }
            case .asyncLet: found = true
            case .assign(let a, _, let b): expr(a); expr(b)
            case .ifStmt(let conds, let a, let b):
                for c in conds {
                    switch c {
                    case .expr(let x), .optionalBinding(_, let x): expr(x)
                    }
                }
                a.forEach(stmt); b?.forEach(stmt)
            case .guardStmt(let conds, let b):
                for c in conds {
                    switch c {
                    case .expr(let x), .optionalBinding(_, let x): expr(x)
                    }
                }
                b.forEach(stmt)
            case .whileStmt(let c, let b), .repeatWhile(let b, let c): expr(c); b.forEach(stmt)
            case .forIn(_, let isAwait, let seq, _, let b):
                if isAwait { found = true }
                expr(seq); b.forEach(stmt)
            case .returnStmt(let e): if let e { expr(e) }
            case .doCatch(let b, let cs): b.forEach(stmt); cs.forEach { $0.body.forEach(stmt) }
            case .switchStmt(let subject, let cs): expr(subject); cs.forEach { $0.body.forEach(stmt) }
            case .deferStmt, .funcDecl, .typeDecl, .breakStmt, .continueStmt: break
            }
        }
        stmts.forEach(stmt)
        return found
    }

    private func compileClosure(_ c: ClosureExpr, _ fs: FunctionState, slot: ClosureSlot, lexical: LexicalRule) {
        let proto = FunctionProto(name: "closure", isPrelude: isPrelude, line: c.loc.line)
        proto.isClosure = true
        let explicitMain = c.attributes.contains("MainActor")
        let isAsync = c.isAsync || containsAwait(c.body) || slot == .asyncInherit
        proto.isAsync = isAsync
        proto.lexicalRule = explicitMain ? .main : lexical

        var awaitDenied: String?
        var throwContext = ThrowContext.inferred
        switch slot {
        case .gcd:
            awaitDenied = "a DispatchQueue block is synchronous, so it can't 'await'. Start a Task { } inside it instead."
            throwContext = .denied("a DispatchQueue block can't throw. Handle the error inside with do/catch or try?.")
        case .sync(let api):
            awaitDenied = "the closure passed to \(api) is synchronous, so it can't 'await'"
        case .async, .asyncInherit, .task, .inferred:
            break
        }

        if explicitMain {
            proto.isolationRule = .main
        } else if slot == .async {
            // A `@Sendable () async` parameter: the closure is nonisolated, and
            // a nonisolated async function runs on the shared pool (SE-0338).
            proto.isAsync = true
            proto.isolationRule = .pool
        } else if isAsync && awaitDenied == nil && (lexical == .enclosing || lexical == .main) {
            proto.isolationRule = .closureLexical
        } else {
            proto.isolationRule = .inherit
        }

        let cfs = FunctionState(proto: proto, parent: fs, typeContext: fs.typeContext, isInstance: fs.isInstance, awaitDenied: awaitDenied, throwContext: throwContext)
        let paramNames: [Param] = c.params.isEmpty && c.maxDollar >= 0
            ? (0...c.maxDollar).map { Param(label: nil, name: "$\($0)", defaultValue: nil, isInout: false, typeText: nil) }
            : c.params
        for p in paramNames {
            let l = cfs.allocate(p.name, isLet: !p.isInout && !p.name.hasPrefix("$"))
            proto.paramSlots.append(l.slot)
            proto.params.append(ParamInfo(label: nil, name: p.name, hasDefault: false, isInout: p.isInout))
        }
        compileBodyWithImplicitReturn(c.body, cfs, line: c.loc.line)
        _ = fs.proto.emit(.makeClosure(proto), line: c.loc.line)
    }
}
