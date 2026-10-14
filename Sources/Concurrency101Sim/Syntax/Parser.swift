/// Recursive-descent parser for the sandbox's Swift subset. Types are
/// skipped (kept as text) because the runtime is dynamically typed.
struct Parser {
    private var tokens: [Token]
    private var pos = 0
    /// Top is false inside `if` / `while` / `guard` / `for` / `switch` heads,
    /// where Swift does not allow a trailing closure.
    private var trailingAllowed: [Bool] = [true]
    /// Highest `$n` seen per closure being parsed.
    private var dollarStack: [Int] = []

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    static func parse(_ source: String) throws -> [Stmt] {
        var lexer = Lexer(source)
        var parser = Parser(tokens: try lexer.tokenize())
        let stmts = try parser.parseStatements(isTopLevel: true)
        if !parser.at(.eof) {
            throw SyntaxError(loc: parser.current.loc, message: "unexpected '\(parser.describe(parser.current))'")
        }
        return stmts
    }

    static func parseExpression(_ source: String, at loc: SourceLocation) throws -> Expr {
        var lexer = Lexer(source, startingAt: loc)
        var parser = Parser(tokens: try lexer.tokenize())
        let expr = try parser.parseExpr()
        if !parser.at(.eof) {
            throw SyntaxError(loc: parser.current.loc, message: "unexpected '\(parser.describe(parser.current))' in string interpolation")
        }
        return expr
    }

    // MARK: - Token helpers

    private var current: Token { tokens[pos] }

    private func token(at offset: Int) -> Token {
        let i = min(pos + offset, tokens.count - 1)
        return tokens[i]
    }

    private func at(_ kind: TokenKind) -> Bool {
        current.kind == kind
    }

    private func atPunct(_ p: String) -> Bool {
        current.kind == .punct(p)
    }

    private func atKeyword(_ k: String) -> Bool {
        current.kind == .keyword(k)
    }

    private func atIdentifier(_ name: String) -> Bool {
        current.kind == .identifier(name)
    }

    @discardableResult
    private mutating func advance() -> Token {
        let t = tokens[pos]
        if pos < tokens.count - 1 { pos += 1 }
        return t
    }

    private mutating func expectPunct(_ p: String, _ context: String = "") throws {
        guard atPunct(p) else {
            let suffix = context.isEmpty ? "" : " \(context)"
            throw SyntaxError(loc: current.loc, message: "expected '\(p)'\(suffix), found '\(describe(current))'")
        }
        advance()
    }

    private mutating func expectKeyword(_ k: String) throws {
        guard atKeyword(k) else {
            throw SyntaxError(loc: current.loc, message: "expected '\(k)', found '\(describe(current))'")
        }
        advance()
    }

    private mutating func expectName(_ what: String) throws -> String {
        if case .identifier(let name) = current.kind {
            advance()
            return name
        }
        throw SyntaxError(loc: current.loc, message: "expected \(what), found '\(describe(current))'")
    }

    /// Member names after `.` may be keywords (`.self`, `.default`, `.init`).
    private mutating func expectMemberName() throws -> String {
        switch current.kind {
        case .identifier(let name), .keyword(let name):
            advance()
            return name
        default:
            throw SyntaxError(loc: current.loc, message: "expected a member name after '.', found '\(describe(current))'")
        }
    }

    func describe(_ token: Token) -> String {
        switch token.kind {
        case .identifier(let s), .keyword(let s), .punct(let s): return s
        case .attribute(let s): return "@" + s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .string: return "string"
        case .dollar(let n): return "$\(n)"
        case .eof: return "end of code"
        }
    }

    // MARK: - Statements

    mutating func parseStatements(isTopLevel: Bool = false) throws -> [Stmt] {
        var stmts: [Stmt] = []
        while true {
            while atPunct(";") { advance() }
            if at(.eof) || atPunct("}") { break }
            if !isTopLevel, atKeyword("case") || atKeyword("default") { break }
            let stmt = try parseStatement()
            stmts.append(stmt)
            if at(.eof) || atPunct("}") || atPunct(";") || current.newlineBefore { continue }
            if !isTopLevel, atKeyword("case") || atKeyword("default") { continue }
            throw SyntaxError(loc: current.loc, message: "put each statement on its own line (or separate them with ';')")
        }
        return stmts
    }

    private mutating func parseBlock() throws -> [Stmt] {
        try expectPunct("{")
        trailingAllowed.append(true)
        defer { trailingAllowed.removeLast() }
        let body = try parseStatements()
        try expectPunct("}", "to close the block")
        return body
    }

    private struct Modifiers {
        var attributes: [String] = []
        var isStatic = false
        var isNonisolated = false
        var loc: SourceLocation

        var isMainActor: Bool { attributes.contains("MainActor") }
    }

    private static let ignoredModifiers: Set<String> = [
        "private", "fileprivate", "internal", "public", "open", "final", "override",
        "mutating", "lazy", "weak", "unowned", "required", "convenience", "dynamic",
    ]

    private mutating func parseModifiers() throws -> Modifiers {
        var mods = Modifiers(loc: current.loc)
        while true {
            switch current.kind {
            case .attribute(let name):
                advance()
                mods.attributes.append(name)
                if atPunct("("), !current.spaceBefore { try skipBalanced("(", ")") }
            case .keyword("static"):
                advance()
                mods.isStatic = true
            case .keyword("class") where token(at: 1).kind == .keyword("func"):
                advance()
                mods.isStatic = true
            case .identifier("nonisolated"):
                advance()
                mods.isNonisolated = true
                if atPunct("("), !current.spaceBefore { try skipBalanced("(", ")") }
            case .identifier(let name) where Self.ignoredModifiers.contains(name) && isDeclarationAhead(offset: 1):
                advance()
                if atPunct("("), !current.spaceBefore { try skipBalanced("(", ")") }
            default:
                return mods
            }
        }
    }

    /// True when a declaration keyword follows (possibly after more modifiers).
    private func isDeclarationAhead(offset: Int) -> Bool {
        var i = offset
        while true {
            let t = token(at: i)
            switch t.kind {
            case .keyword("let"), .keyword("var"), .keyword("func"), .keyword("class"),
                 .keyword("enum"), .keyword("struct"), .keyword("static"), .keyword("init"),
                 .attribute:
                return true
            case .identifier("actor"), .identifier("nonisolated"):
                return true
            case .identifier(let name) where Self.ignoredModifiers.contains(name):
                i += 1
            case .punct("("):
                // private(set)
                i += 3
            default:
                return false
            }
        }
    }

    private mutating func parseStatement() throws -> Stmt {
        let loc = current.loc
        let mods = try parseModifiers()
        let hasModifiers = !mods.attributes.isEmpty || mods.isStatic || mods.isNonisolated

        switch current.kind {
        case .keyword("let"), .keyword("var"):
            return try parseVarDecl()
        case .identifier("async") where token(at: 1).kind == .keyword("let"):
            advance()
            advance()
            let name = try expectName("a name after 'async let'")
            if atPunct(":") {
                advance()
                _ = try parseType()
            }
            try expectPunct("=", "after the async let name")
            let value = try parseExpr()
            return Stmt(kind: .asyncLet(name, value), loc: loc)
        case .keyword("func"):
            return Stmt(kind: .funcDecl(try parseFunc(mods)), loc: loc)
        case .identifier("actor") where isTypeNameAhead():
            return Stmt(kind: .typeDecl(try parseTypeDecl(.actorType, mods)), loc: loc)
        case .keyword("class"):
            return Stmt(kind: .typeDecl(try parseTypeDecl(.classType, mods)), loc: loc)
        case .keyword("enum"):
            return Stmt(kind: .typeDecl(try parseTypeDecl(.namespace, mods)), loc: loc)
        case .keyword("struct"):
            throw SyntaxError(loc: loc, message: "struct isn't supported in the sandbox yet. Use class or actor.")
        case .identifier("protocol"), .identifier("extension"):
            throw SyntaxError(loc: loc, message: "\(describe(current)) isn't supported in the sandbox yet")
        default:
            break
        }

        if hasModifiers {
            throw SyntaxError(loc: current.loc, message: "expected a declaration after the modifiers")
        }

        switch current.kind {
        case .keyword("if"):
            return try parseIf()
        case .keyword("guard"):
            advance()
            let conds = try parseConditions()
            try expectKeyword("else")
            let body = try parseBlock()
            return Stmt(kind: .guardStmt(conds, body), loc: loc)
        case .keyword("while"):
            advance()
            let cond = try withoutTrailing { try $0.parseExpr() }
            let body = try parseBlock()
            return Stmt(kind: .whileStmt(cond, body), loc: loc)
        case .keyword("repeat"):
            advance()
            let body = try parseBlock()
            try expectKeyword("while")
            let cond = try parseExpr()
            return Stmt(kind: .repeatWhile(body, cond), loc: loc)
        case .keyword("for"):
            return try parseFor()
        case .keyword("return"):
            advance()
            if at(.eof) || atPunct("}") || atPunct(";") || current.newlineBefore
                || atKeyword("case") || atKeyword("default") {
                return Stmt(kind: .returnStmt(nil), loc: loc)
            }
            return Stmt(kind: .returnStmt(try parseExpr()), loc: loc)
        case .keyword("break"):
            advance()
            return Stmt(kind: .breakStmt, loc: loc)
        case .keyword("continue"):
            advance()
            return Stmt(kind: .continueStmt, loc: loc)
        case .keyword("throw"):
            advance()
            return Stmt(kind: .throwStmt(try parseExpr()), loc: loc)
        case .keyword("do"):
            return try parseDo()
        case .keyword("defer"):
            advance()
            return Stmt(kind: .deferStmt(try parseBlock()), loc: loc)
        case .keyword("switch"):
            return try parseSwitch()
        default:
            break
        }

        let expr = try parseExpr()
        if case .punct(let op) = current.kind, ["=", "+=", "-=", "*=", "/=", "%="].contains(op) {
            advance()
            let value = try parseExpr()
            return Stmt(kind: .assign(expr, op, value), loc: loc)
        }
        return Stmt(kind: .expr(expr), loc: loc)
    }

    private func isTypeNameAhead() -> Bool {
        if case .identifier = token(at: 1).kind { return true }
        return false
    }

    private mutating func withoutTrailing<T>(_ body: (inout Parser) throws -> T) rethrows -> T {
        trailingAllowed.append(false)
        defer { trailingAllowed.removeLast() }
        return try body(&self)
    }

    private mutating func withTrailing<T>(_ body: (inout Parser) throws -> T) rethrows -> T {
        trailingAllowed.append(true)
        defer { trailingAllowed.removeLast() }
        return try body(&self)
    }

    private mutating func parsePattern() throws -> Pattern {
        if atPunct("(") {
            advance()
            var items: [Pattern] = []
            while !atPunct(")") {
                items.append(try parsePattern())
                if atPunct(",") { advance() } else { break }
            }
            try expectPunct(")", "to close the pattern")
            return .tuple(items)
        }
        let name = try expectName("a name")
        return name == "_" ? .wildcard : .name(name)
    }

    private mutating func parseVarDecl() throws -> Stmt {
        let loc = current.loc
        let isLet = atKeyword("let")
        advance()
        let pattern = try parsePattern()
        if atPunct(":") {
            advance()
            _ = try parseType()
        }
        var initializer: Expr?
        if atPunct("=") {
            advance()
            initializer = try parseExpr()
        }
        return Stmt(kind: .varDecl(isLet: isLet, pattern, initializer), loc: loc)
    }

    private mutating func parseConditions() throws -> [Condition] {
        try withoutTrailing { p in
            var conds: [Condition] = []
            repeat {
                if p.atPunct(",") { p.advance() }
                if p.atKeyword("let") || p.atKeyword("var") {
                    p.advance()
                    let nameLoc = p.current.loc
                    let name = try p.expectName("a name after 'let'")
                    if p.atPunct(":") {
                        p.advance()
                        _ = try p.parseType()
                    }
                    if p.atPunct("=") {
                        p.advance()
                        conds.append(.optionalBinding(name, try p.parseExpr()))
                    } else {
                        conds.append(.optionalBinding(name, Expr(kind: .identifier(name), loc: nameLoc)))
                    }
                } else if p.atKeyword("case") {
                    throw SyntaxError(loc: p.current.loc, message: "'if case' patterns aren't supported in the sandbox yet")
                } else {
                    conds.append(.expr(try p.parseExpr()))
                }
            } while p.atPunct(",")
            return conds
        }
    }

    private mutating func parseIf() throws -> Stmt {
        let loc = current.loc
        try expectKeyword("if")
        let conds = try parseConditions()
        let then = try parseBlock()
        var elseBody: [Stmt]?
        if atKeyword("else") {
            advance()
            if atKeyword("if") {
                elseBody = [try parseIf()]
            } else {
                elseBody = try parseBlock()
            }
        }
        return Stmt(kind: .ifStmt(conds, then, elseBody), loc: loc)
    }

    private mutating func parseFor() throws -> Stmt {
        let loc = current.loc
        try expectKeyword("for")
        var isAwait = false
        if atKeyword("try") { advance() }
        if atKeyword("await") {
            advance()
            isAwait = true
        }
        if atKeyword("case") {
            throw SyntaxError(loc: current.loc, message: "'for case' patterns aren't supported in the sandbox yet")
        }
        let pattern = try parsePattern()
        if atPunct(":") {
            advance()
            _ = try parseType()
        }
        try expectKeyword("in")
        let sequence = try withoutTrailing { try $0.parseExpr() }
        var whereClause: Expr?
        if atKeyword("where") {
            advance()
            whereClause = try withoutTrailing { try $0.parseExpr() }
        }
        let body = try parseBlock()
        return Stmt(kind: .forIn(pattern, isAwait: isAwait, sequence, whereClause, body), loc: loc)
    }

    private mutating func parseDo() throws -> Stmt {
        let loc = current.loc
        try expectKeyword("do")
        let body = try parseBlock()
        var clauses: [CatchClause] = []
        while atKeyword("catch") {
            let cloc = current.loc
            advance()
            var pattern = CatchPattern.any
            if atKeyword("is") {
                advance()
                pattern = .isType(try parseType())
            } else if atKeyword("let") || atKeyword("var") {
                advance()
                let name = try expectName("a name after 'catch let'")
                var typeName: String?
                if atKeyword("as") {
                    advance()
                    typeName = try parseType()
                }
                pattern = .bind(name, typeName)
            } else if !atPunct("{") {
                throw SyntaxError(loc: current.loc, message: "the sandbox supports 'catch', 'catch is Type' and 'catch let name'")
            }
            if atKeyword("where") {
                throw SyntaxError(loc: current.loc, message: "'catch … where' isn't supported in the sandbox yet")
            }
            clauses.append(CatchClause(pattern: pattern, body: try parseBlock(), loc: cloc))
        }
        return Stmt(kind: .doCatch(body, clauses), loc: loc)
    }

    private mutating func parseSwitch() throws -> Stmt {
        let loc = current.loc
        try expectKeyword("switch")
        let subject = try withoutTrailing { try $0.parseExpr() }
        try expectPunct("{")
        var cases: [SwitchCase] = []
        while !atPunct("}") {
            let cloc = current.loc
            if atKeyword("default") {
                advance()
                try expectPunct(":")
                let body = try withTrailing { try $0.parseStatements() }
                cases.append(SwitchCase(patterns: [], bindName: nil, body: body, loc: cloc))
                continue
            }
            try expectKeyword("case")
            var patterns: [Expr] = []
            var bindName: String?
            if atKeyword("let") {
                advance()
                bindName = try expectName("a name after 'case let'")
            } else {
                repeat {
                    if atPunct(",") { advance() }
                    patterns.append(try withoutTrailing { try $0.parseExpr() })
                } while atPunct(",")
            }
            try expectPunct(":")
            let body = try withTrailing { try $0.parseStatements() }
            cases.append(SwitchCase(patterns: patterns, bindName: bindName, body: body, loc: cloc))
        }
        try expectPunct("}")
        return Stmt(kind: .switchStmt(subject, cases), loc: loc)
    }

    // MARK: - Declarations

    private mutating func parseParams() throws -> [Param] {
        try expectPunct("(")
        var params: [Param] = []
        while !atPunct(")") {
            var first: String
            switch current.kind {
            case .identifier(let s), .keyword(let s):
                first = s
                advance()
            default:
                throw SyntaxError(loc: current.loc, message: "expected a parameter name, found '\(describe(current))'")
            }
            var label: String? = first
            var name = first
            if case .identifier(let second) = current.kind {
                name = second
                advance()
            }
            if label == "_" { label = nil }
            var isInout = false
            var typeText: String?
            if atPunct(":") {
                advance()
                if atKeyword("inout") {
                    advance()
                    isInout = true
                }
                typeText = try parseType()
                if typeText?.hasPrefix("inout ") == true { isInout = true }
            }
            var defaultValue: Expr?
            if atPunct("=") {
                advance()
                defaultValue = try parseExpr()
            }
            params.append(Param(label: label, name: name, defaultValue: defaultValue, isInout: isInout, typeText: typeText))
            if atPunct(",") { advance() } else { break }
        }
        try expectPunct(")", "to close the parameter list")
        return params
    }

    private mutating func skipEffects() -> (isAsync: Bool, throwsFlag: Bool) {
        var isAsync = false
        var throwsFlag = false
        while true {
            if atIdentifier("async") {
                advance()
                isAsync = true
            } else if atKeyword("throws") || atKeyword("rethrows") {
                advance()
                throwsFlag = true
                if atPunct("("), !current.spaceBefore { try? skipBalanced("(", ")") }
            } else {
                return (isAsync, throwsFlag)
            }
        }
    }

    private mutating func parseFunc(_ mods: Modifiers) throws -> FuncDecl {
        let loc = mods.loc
        try expectKeyword("func")
        let name = try expectName("a function name")
        if atPunct("<") { try skipBalanced("<", ">") }
        let params = try parseParams()
        let effects = skipEffects()
        if atPunct("->") {
            advance()
            _ = try parseType()
        }
        if atKeyword("where") { try skipUntilBrace() }
        let body = try parseBlock()
        return FuncDecl(
            name: name, params: params, isAsync: effects.isAsync, throwsFlag: effects.throwsFlag,
            isStatic: mods.isStatic, isMainActor: mods.isMainActor, isNonisolated: mods.isNonisolated,
            isInit: false, body: body, loc: loc
        )
    }

    private mutating func parseTypeDecl(_ kind: TypeKind, _ mods: Modifiers) throws -> TypeDecl {
        let loc = mods.loc
        advance()
        let name = try expectName("a type name")
        let decl = TypeDecl(kind: kind, name: name, isMainActor: mods.isMainActor, loc: loc)
        if atPunct("<") { try skipBalanced("<", ">") }
        if atPunct(":") {
            advance()
            repeat {
                if atPunct(",") { advance() }
                _ = try parseType()
            } while atPunct(",")
        }
        if atKeyword("where") { try skipUntilBrace() }
        try expectPunct("{")
        while !atPunct("}") {
            while atPunct(";") { advance() }
            if atPunct("}") { break }
            try parseMember(into: decl)
        }
        try expectPunct("}", "to close \(name)")
        return decl
    }

    private mutating func parseMember(into decl: TypeDecl) throws {
        let mods = try parseModifiers()
        let loc = mods.loc
        switch current.kind {
        case .keyword("case"):
            guard decl.kind == .namespace else {
                throw SyntaxError(loc: loc, message: "'case' only belongs in an enum")
            }
            advance()
            repeat {
                if atPunct(",") { advance() }
                let caseName = try expectName("a case name")
                if atPunct("(") {
                    throw SyntaxError(loc: current.loc, message: "enum cases with associated values aren't supported in the sandbox yet")
                }
                if atPunct("=") {
                    advance()
                    _ = try parseExpr()
                }
                decl.cases.append(caseName)
            } while atPunct(",")
        case .keyword("let"), .keyword("var"):
            let isLet = atKeyword("let")
            advance()
            let name = try expectName("a property name")
            if atPunct(":") {
                advance()
                _ = try parseType()
            }
            if atPunct("{") {
                let body = try parseComputedBody()
                decl.computed.append(ComputedProperty(name: name, isStatic: mods.isStatic, isMainActor: mods.isMainActor, body: body, loc: loc))
                return
            }
            var initializer: Expr?
            if atPunct("=") {
                advance()
                initializer = try parseExpr()
            }
            if decl.kind == .namespace && !mods.isStatic {
                throw SyntaxError(loc: loc, message: "an enum can't hold stored properties; use 'static let' or a class")
            }
            decl.stored.append(StoredProperty(name: name, isLet: isLet, isStatic: mods.isStatic, initializer: initializer, loc: loc))
        case .keyword("func"):
            let fn = try parseFunc(mods)
            if decl.kind == .namespace && !fn.isStatic {
                throw SyntaxError(loc: loc, message: "functions in an enum namespace must be 'static' in the sandbox")
            }
            if decl.isMainActor { fn.isMainActor = true }
            decl.funcs.append(fn)
        case .keyword("init"):
            advance()
            if atPunct("?") || atPunct("!") { advance() }
            let params = try parseParams()
            let effects = skipEffects()
            let body = try parseBlock()
            decl.funcs.append(FuncDecl(
                name: "init", params: params, isAsync: effects.isAsync, throwsFlag: effects.throwsFlag,
                isStatic: false, isMainActor: mods.isMainActor || decl.isMainActor, isNonisolated: mods.isNonisolated,
                isInit: true, body: body, loc: loc
            ))
        case .identifier("deinit"):
            advance()
            _ = try parseBlock()
        case .identifier("actor") where isTypeNameAhead():
            decl.nested.append(try parseTypeDecl(.actorType, mods))
        case .keyword("class"):
            decl.nested.append(try parseTypeDecl(.classType, mods))
        case .keyword("enum"):
            decl.nested.append(try parseTypeDecl(.namespace, mods))
        case .keyword("struct"):
            throw SyntaxError(loc: current.loc, message: "struct isn't supported in the sandbox yet. Use class or actor.")
        default:
            throw SyntaxError(loc: current.loc, message: "expected a property, function or init inside \(decl.name), found '\(describe(current))'")
        }
    }

    /// `{ body }` or `{ get { body } }` for a read-only computed property.
    private mutating func parseComputedBody() throws -> [Stmt] {
        try expectPunct("{")
        if atIdentifier("get") {
            advance()
            _ = skipEffects()
            let body = try parseBlock()
            if atIdentifier("set") {
                throw SyntaxError(loc: current.loc, message: "computed setters aren't supported in the sandbox yet")
            }
            try expectPunct("}")
            return body
        }
        trailingAllowed.append(true)
        defer { trailingAllowed.removeLast() }
        let body = try parseStatements()
        try expectPunct("}", "to close the computed property")
        return body
    }

    // MARK: - Types (skipped, kept as text)

    @discardableResult
    mutating func parseType() throws -> String {
        var text = ""
        while case .attribute(let a) = current.kind {
            advance()
            text += "@\(a) "
        }
        if atKeyword("inout") {
            advance()
            text += "inout "
        }
        if atIdentifier("some") || atIdentifier("any") || atIdentifier("sending") {
            text += describe(current) + " "
            advance()
        }
        if atPunct("(") {
            advance()
            var parts: [String] = []
            while !atPunct(")") {
                if case .identifier = current.kind, token(at: 1).kind == .punct(":") {
                    advance()
                    advance()
                } else if case .identifier = current.kind, case .identifier = token(at: 1).kind, token(at: 2).kind == .punct(":") {
                    advance(); advance(); advance()
                }
                parts.append(try parseType())
                if atPunct(",") { advance() } else { break }
            }
            try expectPunct(")", "to close the type")
            text += "(" + parts.joined(separator: ", ") + ")"
            let effects = skipEffects()
            if atPunct("->") {
                advance()
                text += (effects.isAsync ? " async" : "") + " -> " + (try parseType())
            }
        } else if atPunct("[") {
            advance()
            let element = try parseType()
            if atPunct(":") {
                advance()
                text += "[\(element): \(try parseType())]"
            } else {
                text += "[\(element)]"
            }
            try expectPunct("]", "to close the type")
        } else {
            var name: String
            switch current.kind {
            case .identifier(let s):
                name = s
                advance()
            case .keyword(let s) where s == "Self":
                name = s
                advance()
            default:
                throw SyntaxError(loc: current.loc, message: "expected a type, found '\(describe(current))'")
            }
            if atPunct("<"), !current.spaceBefore { name += try skipBalancedText("<", ">") }
            while atPunct("."), case .identifier(let next) = token(at: 1).kind {
                advance()
                advance()
                name += "." + next
                if atPunct("<"), !current.spaceBefore { name += try skipBalancedText("<", ">") }
            }
            text += name
        }
        while (atPunct("?") || atPunct("!")) && !current.spaceBefore {
            text += describe(current)
            advance()
        }
        return text
    }

    private mutating func skipBalanced(_ open: String, _ close: String) throws {
        _ = try skipBalancedText(open, close)
    }

    private mutating func skipBalancedText(_ open: String, _ close: String) throws -> String {
        let start = current.loc
        var depth = 0
        var text = ""
        repeat {
            if at(.eof) {
                throw SyntaxError(loc: start, message: "missing '\(close)'")
            }
            if atPunct(open) { depth += 1 }
            if atPunct(close) { depth -= 1 }
            text += describe(current)
            advance()
        } while depth > 0
        return text
    }

    private mutating func skipUntilBrace() throws {
        while !atPunct("{") {
            if at(.eof) {
                throw SyntaxError(loc: current.loc, message: "expected '{'")
            }
            advance()
        }
    }

    // MARK: - Expressions

    private static let precedence: [String: Int] = [
        "||": 1, "&&": 2,
        "==": 3, "!=": 3, "<": 3, ">": 3, "<=": 3, ">=": 3,
        "??": 4,
        "..<": 6, "...": 6,
        "+": 7, "-": 7,
        "*": 8, "/": 8, "%": 8,
    ]
    private static let castingPrecedence = 5

    mutating func parseExpr() throws -> Expr {
        let cond = try parseBinary(minPrec: 1)
        if atPunct("?"), current.spaceBefore {
            advance()
            let a = try parseExpr()
            try expectPunct(":", "in the ?: expression")
            let b = try parseExpr()
            return Expr(kind: .ternary(cond, a, b), loc: cond.loc)
        }
        return cond
    }

    private mutating func parseBinary(minPrec: Int) throws -> Expr {
        var lhs = try parsePrefix()
        while true {
            if (atKeyword("is") || atKeyword("as")) && Self.castingPrecedence >= minPrec {
                let isCheck = atKeyword("is")
                advance()
                var kind: TryKind?
                if !isCheck, (atPunct("?") || atPunct("!")), !current.spaceBefore {
                    kind = atPunct("?") ? .optional : .forced
                    advance()
                }
                let typeName = try parseType()
                lhs = Expr(kind: isCheck ? .isType(lhs, typeName) : .cast(lhs, typeName, kind), loc: lhs.loc)
                continue
            }
            guard case .punct(let op) = current.kind, let prec = Self.precedence[op], prec >= minPrec else {
                break
            }
            // `a < b` vs a postfix `!`: binary operators need matching whitespace.
            if current.newlineBefore && (op == "-" || op == "+") { break }
            advance()
            let rhs = op == "??" ? try parseBinary(minPrec: prec) : try parseBinary(minPrec: prec + 1)
            lhs = Expr(kind: .binary(op, lhs, rhs), loc: lhs.loc)
        }
        return lhs
    }

    private mutating func parsePrefix() throws -> Expr {
        let loc = current.loc
        if atKeyword("try") {
            advance()
            var kind = TryKind.plain
            if (atPunct("?") || atPunct("!")) && !current.spaceBefore {
                kind = atPunct("?") ? .optional : .forced
                advance()
            }
            let inner = try parseBinary(minPrec: 1)
            return Expr(kind: .tryExpr(inner, kind), loc: loc)
        }
        if atKeyword("await") {
            advance()
            let inner = try parseBinary(minPrec: 1)
            return Expr(kind: .awaitExpr(inner), loc: loc)
        }
        if atPunct("-") || atPunct("!") {
            let op = describe(current)
            advance()
            let operand = try parsePrefix()
            if op == "-", case .int(let i) = operand.kind { return Expr(kind: .int(-i), loc: loc) }
            if op == "-", case .double(let d) = operand.kind { return Expr(kind: .double(-d), loc: loc) }
            return Expr(kind: .prefix(op, operand), loc: loc)
        }
        if atPunct("&") {
            advance()
            return Expr(kind: .inoutRef(try parsePostfix(try parsePrimary())), loc: loc)
        }
        return try parsePostfix(try parsePrimary())
    }

    private mutating func parsePrimary() throws -> Expr {
        let tok = current
        let loc = tok.loc
        switch tok.kind {
        case .int(let i):
            advance()
            return Expr(kind: .int(i), loc: loc)
        case .double(let d):
            advance()
            return Expr(kind: .double(d), loc: loc)
        case .string(let parts):
            advance()
            var out: [InterpolationPart] = []
            for part in parts {
                switch part {
                case .text(let s):
                    out.append(.text(s))
                case .interpolation(let source, let at):
                    out.append(.expr(try Parser.parseExpression(source, at: at)))
                }
            }
            return Expr(kind: .string(out), loc: loc)
        case .keyword("true"):
            advance()
            return Expr(kind: .bool(true), loc: loc)
        case .keyword("false"):
            advance()
            return Expr(kind: .bool(false), loc: loc)
        case .keyword("nil"):
            advance()
            return Expr(kind: .nilLiteral, loc: loc)
        case .keyword("self"):
            advance()
            return Expr(kind: .selfRef, loc: loc)
        case .keyword("Self"):
            advance()
            return Expr(kind: .identifier("Self"), loc: loc)
        case .keyword("init"):
            advance()
            return Expr(kind: .identifier("init"), loc: loc)
        case .identifier(let name):
            advance()
            return Expr(kind: .identifier(name), loc: loc)
        case .dollar(let n):
            advance()
            if !dollarStack.isEmpty {
                dollarStack[dollarStack.count - 1] = max(dollarStack[dollarStack.count - 1], n)
            } else {
                throw SyntaxError(loc: loc, message: "$\(n) can only be used inside a closure")
            }
            return Expr(kind: .dollar(n), loc: loc)
        case .punct("."):
            advance()
            let name = try expectMemberName()
            return Expr(kind: .implicitMember(name), loc: loc)
        case .punct("("):
            advance()
            let items = try withTrailing { p -> [Expr] in
                var items: [Expr] = []
                while !p.atPunct(")") {
                    if case .identifier = p.current.kind, p.token(at: 1).kind == .punct(":") {
                        p.advance()
                        p.advance()
                    }
                    items.append(try p.parseExpr())
                    if p.atPunct(",") { p.advance() } else { break }
                }
                return items
            }
            try expectPunct(")", "to close the parentheses")
            if items.count == 1 { return items[0] }
            return Expr(kind: .tuple(items), loc: loc)
        case .punct("["):
            advance()
            let items = try withTrailing { p -> [Expr] in
                var items: [Expr] = []
                while !p.atPunct("]") {
                    items.append(try p.parseExpr())
                    if p.atPunct(":") {
                        throw SyntaxError(loc: p.current.loc, message: "dictionaries aren't supported in the sandbox yet")
                    }
                    if p.atPunct(",") { p.advance() } else { break }
                }
                return items
            }
            try expectPunct("]", "to close the array")
            return Expr(kind: .array(items), loc: loc)
        case .punct("{"):
            return try parseClosure()
        default:
            throw SyntaxError(loc: loc, message: "expected an expression, found '\(describe(tok))'")
        }
    }

    private mutating func parsePostfix(_ start: Expr) throws -> Expr {
        var expr = start
        while true {
            let tok = current
            switch tok.kind {
            case .punct("."):
                advance()
                if case .int(let i) = current.kind {
                    advance()
                    expr = Expr(kind: .tupleIndex(expr, i), loc: expr.loc)
                } else if case .double(let d) = current.kind {
                    // `pair.0.1` lexes as a double; split it back into two indexes.
                    advance()
                    let parts = String(d).split(separator: ".").compactMap { Int($0) }
                    for i in parts { expr = Expr(kind: .tupleIndex(expr, i), loc: expr.loc) }
                } else {
                    let name = try expectMemberName()
                    expr = Expr(kind: .member(expr, name), loc: expr.loc)
                }
            case .punct("?.") where !tok.spaceBefore:
                advance()
                let name = try expectMemberName()
                expr = Expr(kind: .optionalMember(expr, name), loc: expr.loc)
            case .punct("(") where !tok.newlineBefore:
                advance()
                let args = try parseArguments(close: ")")
                expr = Expr(kind: .call(expr, args), loc: expr.loc)
            case .punct("[") where !tok.newlineBefore && !tok.spaceBefore:
                advance()
                let index = try withTrailing { try $0.parseExpr() }
                try expectPunct("]", "to close the subscript")
                expr = Expr(kind: .subscriptIndex(expr, index), loc: expr.loc)
            case .punct("!") where !tok.spaceBefore:
                advance()
                expr = Expr(kind: .forceUnwrap(expr), loc: expr.loc)
            case .punct("<") where !tok.spaceBefore && genericArgumentsAhead():
                try skipBalanced("<", ">")
            case .punct("{") where !tok.newlineBefore && (trailingAllowed.last ?? true):
                let closure = try parseClosure()
                var args: [Argument] = []
                var callee = expr
                if case .call(let c, let existing) = expr.kind {
                    callee = c
                    args = existing
                }
                args.append(Argument(label: nil, value: closure, isTrailingClosure: true))
                while case .identifier(let label) = current.kind,
                      token(at: 1).kind == .punct(":"),
                      token(at: 2).kind == .punct("{") {
                    advance()
                    advance()
                    args.append(Argument(label: label, value: try parseClosure(), isTrailingClosure: true))
                }
                expr = Expr(kind: .call(callee, args), loc: expr.loc)
            default:
                return expr
            }
        }
    }

    /// `ExclusiveState<Int>(0)`: a `<` that closes before `(` or `.` is a
    /// generic argument list, not a comparison.
    private func genericArgumentsAhead() -> Bool {
        var depth = 0
        var i = 0
        while i < 40 {
            let t = token(at: i)
            switch t.kind {
            case .punct("<"): depth += 1
            case .punct(">"):
                depth -= 1
                if depth == 0 {
                    let next = token(at: i + 1).kind
                    return next == .punct("(") || next == .punct(".")
                }
            case .identifier, .punct(","), .punct("."), .punct("?"), .punct("["), .punct("]"), .punct(":"), .keyword("Self"):
                break
            default:
                return false
            }
            i += 1
        }
        return false
    }

    private mutating func parseArguments(close: String) throws -> [Argument] {
        try withTrailing { p in
            var args: [Argument] = []
            while !p.atPunct(close) {
                var label: String?
                switch p.current.kind {
                case .identifier(let s) where p.token(at: 1).kind == .punct(":"):
                    label = s
                    p.advance()
                    p.advance()
                case .keyword(let s) where p.token(at: 1).kind == .punct(":"):
                    label = s
                    p.advance()
                    p.advance()
                default:
                    break
                }
                args.append(Argument(label: label, value: try p.parseExpr()))
                if p.atPunct(",") { p.advance() } else { break }
            }
            try p.expectPunct(close, "to close the argument list")
            return args
        }
    }

    // MARK: - Closures

    private mutating func parseClosure() throws -> Expr {
        let loc = current.loc
        try expectPunct("{")
        var attributes: [String] = []
        var params: [Param] = []
        var isAsync = false
        var throwsFlag = false
        if closureHasSignature() {
            while case .attribute(let a) = current.kind {
                attributes.append(a)
                advance()
            }
            if atPunct("[") { try skipBalanced("[", "]") }
            if atPunct("(") {
                advance()
                while !atPunct(")") {
                    let name = try expectName("a closure parameter")
                    if case .identifier(let second) = current.kind {
                        advance()
                        params.append(Param(label: nil, name: second, defaultValue: nil, isInout: false, typeText: nil))
                    } else {
                        params.append(Param(label: nil, name: name, defaultValue: nil, isInout: false, typeText: nil))
                    }
                    if atPunct(":") {
                        advance()
                        let t = try parseType()
                        if t.hasPrefix("inout ") { params[params.count - 1].isInout = true }
                    }
                    if atPunct(",") { advance() } else { break }
                }
                try expectPunct(")", "to close the closure parameters")
            } else {
                while case .identifier(let name) = current.kind {
                    advance()
                    params.append(Param(label: nil, name: name, defaultValue: nil, isInout: false, typeText: nil))
                    if atPunct(",") { advance() } else { break }
                }
            }
            let effects = skipEffects()
            isAsync = effects.isAsync
            throwsFlag = effects.throwsFlag
            if atPunct("->") {
                advance()
                _ = try parseType()
            }
            try expectKeyword("in")
        }
        dollarStack.append(-1)
        trailingAllowed.append(true)
        let body: [Stmt]
        do {
            body = try parseStatements()
        } catch {
            trailingAllowed.removeLast()
            dollarStack.removeLast()
            throw error
        }
        trailingAllowed.removeLast()
        let maxDollar = dollarStack.removeLast()
        try expectPunct("}", "to close the closure")
        if maxDollar >= 0 && !params.isEmpty {
            throw SyntaxError(loc: loc, message: "a closure with named parameters can't also use $0")
        }
        let closure = ClosureExpr(
            params: params, attributes: attributes, body: body, isAsync: isAsync,
            throwsFlag: throwsFlag, loc: loc, maxDollar: maxDollar
        )
        return Expr(kind: .closure(closure), loc: loc)
    }

    /// Looks ahead from just after `{` for `… in` on the same line, made only
    /// of tokens that can appear in a closure signature.
    private func closureHasSignature() -> Bool {
        var i = 0
        var depth = 0
        while true {
            let t = token(at: i)
            if i > 0 && t.newlineBefore { return false }
            switch t.kind {
            case .keyword("in") where depth == 0:
                return i > 0
            case .identifier, .attribute, .keyword("self"), .keyword("throws"), .keyword("inout"), .keyword("Self"):
                break
            case .punct("("), .punct("["):
                depth += 1
            case .punct(")"), .punct("]"):
                depth -= 1
            case .punct(","), .punct(":"), .punct("->"), .punct("."), .punct("?"), .punct("!"),
                 .punct("<"), .punct(">"), .punct("="), .punct("&"):
                break
            default:
                return false
            }
            i += 1
        }
    }
}
