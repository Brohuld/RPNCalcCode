import Foundation

// MARK: - Types publics

enum AngleMode: String, Codable, CaseIterable {
    case deg, rad, grad
}

enum DisplayFormat: String, Codable, CaseIterable {
    case fix, sci, eng
}

enum CalcError: String, Codable {
    case math
    case overflow
}

enum PendingOperation: String, Codable {
    case store, recall
}

/// Toutes les actions que le moteur sait exécuter.
enum Key: Hashable, Codable {
    // Saisie
    case digit(Int), point, eex, chs, backspace
    // Pile
    case enter, clx, clearStack, swapXY, rollDown, rollUp, lastX
    // Arithmétique
    case add, subtract, multiply, divide
    // Mémoires
    case sto, rcl, clearRegisters
    // Fonctions
    case sqrt, square, power, root, reciprocal, factorial, percent, deltaPercent
    case sin, cos, tan, asin, acos, atan
    case ln, exp, log, exp10
    case pi, abs, intPart, fracPart, round
}

/// Texte affiché : mantisse + exposant éventuel (séparateur décimal toujours ".").
struct DisplayText: Equatable {
    var mantissa: String
    var exponent: String?
}

// MARK: - Saisie d'un nombre

private struct NumberEntry: Codable, Equatable {
    static let maxDigits = 10

    var mantissa = ""          // chiffres et éventuellement "."
    var negative = false
    var exponent: String?      // nil = pas d'EEX ; "" = EEX pressé, pas encore de chiffre
    var exponentNegative = false

    var digitCount: Int { mantissa.filter(\.isNumber).count }

    var value: Double {
        var m = mantissa
        if m.isEmpty { m = "0" }
        if m.hasPrefix(".") { m = "0" + m }
        if m.hasSuffix(".") { m += "0" }
        var s = (negative ? "-" : "") + m
        if let e = exponent, !e.isEmpty {
            s += "e" + (exponentNegative ? "-" : "") + e
        }
        return Double(s) ?? 0
    }

    var display: DisplayText {
        let m = (negative ? "-" : "") + (mantissa.isEmpty ? "0" : mantissa)
        guard let e = exponent else { return DisplayText(mantissa: m, exponent: nil) }
        let padded = String(repeating: "0", count: max(0, 2 - e.count)) + e
        return DisplayText(mantissa: m, exponent: (exponentNegative ? "-" : "") + padded)
    }
}

// MARK: - Moteur RPN (pile à 4 niveaux, façon HP-11C)

struct RPNEngine: Codable, Equatable {
    static let registerCount = 10

    private(set) var x = 0.0
    private(set) var y = 0.0
    private(set) var z = 0.0
    private(set) var t = 0.0
    private(set) var lastXValue = 0.0
    private(set) var registers = Array(repeating: 0.0, count: RPNEngine.registerCount)
    private(set) var error: CalcError?
    private(set) var pending: PendingOperation?

    var angleMode: AngleMode = .deg
    var displayFormat: DisplayFormat = .fix
    var displayDigits: Int = 4 {
        didSet { displayDigits = min(max(displayDigits, 0), 9) }
    }

    private var stackLiftEnabled = true
    private var entry: NumberEntry?

    var isEntering: Bool { entry != nil }

    // MARK: Affichage

    var xDisplay: DisplayText {
        if let entry { return entry.display }
        return Self.format(x, displayFormat, displayDigits)
    }

    func display(_ value: Double) -> DisplayText {
        Self.format(value, displayFormat, displayDigits)
    }

    // MARK: Point d'entrée unique

    mutating func press(_ key: Key) {
        // Une erreur affichée est effacée par n'importe quelle touche (touche ignorée).
        if error != nil {
            error = nil
            return
        }

        // STO / RCL attendent un numéro de registre.
        if let op = pending {
            pending = nil
            if case .digit(let n) = key {
                performRegister(op, n)
            }
            return
        }

        switch key {
        case .digit(let d): typeDigit(d)
        case .point:        typePoint()
        case .eex:          typeEEX()
        case .chs:          changeSign()
        case .backspace:    backspace()
        default:
            commitEntry()
            execute(key)
        }
    }

    mutating func clearError() { error = nil }

    /// Place une valeur dans X (collage), comme si on l'avait tapée.
    mutating func enterValue(_ value: Double) {
        guard value.isFinite else { return }
        error = nil
        pending = nil
        commitEntry()
        push(value == 0 ? 0 : value)
    }

    /// Lit un nombre dans un texte collé : accepte "," ou "." décimal,
    /// séparateurs de milliers, signe moins typographique et notation E.
    static func parseNumber(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for sep in [" ", "\u{00A0}", "\u{202F}", "'", "’"] {
            s = s.replacingOccurrences(of: sep, with: "")
        }
        s = s.replacingOccurrences(of: "−", with: "-")
        s = s.replacingOccurrences(of: "×10^", with: "e")
        let lastComma = s.lastIndex(of: ",")
        let lastPoint = s.lastIndex(of: ".")
        if let c = lastComma, let p = lastPoint {
            // Les deux présents : le dernier est le séparateur décimal.
            if c > p {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if lastComma != nil {
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        guard !s.isEmpty, let v = Double(s), v.isFinite else { return nil }
        return v
    }

    // MARK: Saisie

    private mutating func beginEntryIfNeeded() {
        guard entry == nil else { return }
        if stackLiftEnabled { liftStack() }
        entry = NumberEntry()
        stackLiftEnabled = true
    }

    private mutating func typeDigit(_ d: Int) {
        beginEntryIfNeeded()
        guard var e = entry else { return }
        if let exp = e.exponent {
            e.exponent = String((exp + String(d)).suffix(2))
        } else {
            guard e.digitCount < NumberEntry.maxDigits else { return }
            if e.mantissa == "0" {
                e.mantissa = String(d)
            } else {
                e.mantissa += String(d)
            }
        }
        entry = e
        x = e.value
    }

    private mutating func typePoint() {
        beginEntryIfNeeded()
        guard var e = entry, e.exponent == nil, !e.mantissa.contains(".") else { return }
        e.mantissa = (e.mantissa.isEmpty ? "0" : e.mantissa) + "."
        entry = e
        x = e.value
    }

    private mutating func typeEEX() {
        beginEntryIfNeeded()
        guard var e = entry, e.exponent == nil else { return }
        if e.mantissa.isEmpty || e.value == 0 { e.mantissa = "1" }
        e.exponent = ""
        entry = e
        x = e.value
    }

    private mutating func changeSign() {
        if var e = entry {
            if e.exponent != nil {
                e.exponentNegative.toggle()
            } else {
                e.negative.toggle()
            }
            entry = e
            x = e.value
        } else {
            x = x == 0 ? 0 : -x
        }
    }

    private mutating func backspace() {
        guard var e = entry else {
            // Hors saisie : efface X (comme CLx).
            x = 0
            stackLiftEnabled = false
            return
        }
        if let exp = e.exponent {
            if exp.isEmpty {
                e.exponent = nil
                e.exponentNegative = false
            } else {
                e.exponent = String(exp.dropLast())
            }
        } else if !e.mantissa.isEmpty {
            e.mantissa.removeLast()
        }
        if e.mantissa.isEmpty && e.exponent == nil {
            entry = nil
            x = 0
            stackLiftEnabled = false
        } else {
            entry = e
            x = e.value
        }
    }

    private mutating func commitEntry() {
        entry = nil
    }

    // MARK: Pile

    private mutating func liftStack() {
        t = z
        z = y
        y = x
    }

    private mutating func dropStack() {
        y = z
        z = t
    }

    private mutating func push(_ value: Double) {
        if stackLiftEnabled { liftStack() }
        x = value
        stackLiftEnabled = true
    }

    // MARK: Exécution

    private mutating func execute(_ key: Key) {
        switch key {
        case .enter:
            liftStack()
            stackLiftEnabled = false
        case .clx:
            x = 0
            stackLiftEnabled = false
        case .clearStack:
            x = 0; y = 0; z = 0; t = 0
            stackLiftEnabled = false
        case .swapXY:
            (x, y) = (y, x)
            stackLiftEnabled = true
        case .rollDown:
            (x, y, z, t) = (y, z, t, x)
            stackLiftEnabled = true
        case .rollUp:
            (x, y, z, t) = (t, x, y, z)
            stackLiftEnabled = true
        case .lastX:
            push(lastXValue)

        case .add:      binary { $0 + $1 }
        case .subtract: binary { $0 - $1 }
        case .multiply: binary { $0 * $1 }
        case .divide:   binary { $1 == 0 ? nil : $0 / $1 }
        case .power:    binary(Self.power)
        case .root:     binary(Self.nthRoot)

        case .sto:      pending = .store
        case .rcl:      pending = .recall
        case .clearRegisters:
            registers = Array(repeating: 0, count: Self.registerCount)

        case .sqrt:       unary { $0 < 0 ? nil : sqrt($0) }
        case .square:     unary { $0 * $0 }
        case .reciprocal: unary { $0 == 0 ? nil : 1 / $0 }
        case .factorial:  unary(Self.factorial)
        case .percent:
            let base = y
            unary { base * $0 / 100 }
        case .deltaPercent:
            let base = y
            unary { base == 0 ? nil : 100 * ($0 - base) / base }

        case .sin, .cos, .tan, .asin, .acos, .atan:
            let mode = angleMode
            unary { Self.trig(key, $0, mode) }

        case .ln:    unary { $0 <= 0 ? nil : log($0) }
        case .exp:   unary { exp($0) }
        case .log:   unary { $0 <= 0 ? nil : log10($0) }
        case .exp10: unary { pow(10, $0) }

        case .pi:       push(Double.pi)
        case .abs:      unary { Swift.abs($0) }
        case .intPart:  unary { $0.rounded(.towardZero) }
        case .fracPart: unary { $0 - $0.rounded(.towardZero) }
        case .round:
            let fmt = displayFormat
            let digits = displayDigits
            unary { Self.roundToDisplay($0, fmt, digits) }

        case .digit, .point, .eex, .chs, .backspace:
            break // traités dans press(_:)
        }
    }

    private mutating func performRegister(_ op: PendingOperation, _ n: Int) {
        guard registers.indices.contains(n) else { return }
        switch op {
        case .store:
            registers[n] = x
            stackLiftEnabled = true
        case .recall:
            push(registers[n])
        }
    }

    /// Opération à deux arguments f(y, x) : la pile descend.
    private mutating func binary(_ f: (Double, Double) -> Double?) {
        guard let r = validated(f(y, x)) else { return }
        lastXValue = x
        x = r
        dropStack()
        stackLiftEnabled = true
    }

    /// Opération sur X seul : la pile ne bouge pas.
    private mutating func unary(_ f: (Double) -> Double?) {
        guard let r = validated(f(x)) else { return }
        lastXValue = x
        x = r
        stackLiftEnabled = true
    }

    /// En cas d'erreur la pile reste intacte (comportement HP).
    private mutating func validated(_ r: Double?) -> Double? {
        guard let r else { error = .math; return nil }
        if r.isNaN { error = .math; return nil }
        if r.isInfinite { error = .overflow; return nil }
        return r == 0 ? 0 : r   // évite l'affichage de "-0"
    }

    // MARK: Fonctions mathématiques

    private static func trig(_ key: Key, _ v: Double, _ mode: AngleMode) -> Double? {
        switch key {
        case .sin:
            return snap(sin(toRadians(v, mode)))
        case .cos:
            return snap(cos(toRadians(v, mode)))
        case .tan:
            let r = toRadians(v, mode)
            let c = snap(cos(r))
            return c == 0 ? nil : snap(sin(r)) / c
        case .asin:
            return Swift.abs(v) > 1 ? nil : fromRadians(asin(v), mode)
        case .acos:
            return Swift.abs(v) > 1 ? nil : fromRadians(acos(v), mode)
        case .atan:
            return fromRadians(atan(v), mode)
        default:
            return nil
        }
    }

    private static func power(_ base: Double, _ e: Double) -> Double? {
        if base == 0 && e <= 0 { return nil }
        return pow(base, e)
    }

    private static func nthRoot(_ value: Double, _ n: Double) -> Double? {
        if n == 0 { return nil }
        if value < 0 {
            // Racine impaire d'un négatif : autorisée.
            guard n == n.rounded(), Swift.abs(n) < 1e15, Int(n) % 2 != 0 else { return nil }
            return -pow(-value, 1 / n)
        }
        return pow(value, 1 / n)
    }

    private static func factorial(_ v: Double) -> Double? {
        if v == v.rounded() {
            if v < 0 { return nil }
            if v > 170 { return .infinity }
            var r = 1.0
            var i = 2.0
            while i <= v { r *= i; i += 1 }
            return r
        }
        return tgamma(v + 1)   // x! = Γ(x+1) pour les non-entiers
    }

    private static func toRadians(_ v: Double, _ mode: AngleMode) -> Double {
        switch mode {
        case .deg:  return v.truncatingRemainder(dividingBy: 360) * .pi / 180
        case .grad: return v.truncatingRemainder(dividingBy: 400) * .pi / 200
        case .rad:  return v
        }
    }

    private static func fromRadians(_ v: Double, _ mode: AngleMode) -> Double {
        switch mode {
        case .deg:  return v * 180 / .pi
        case .grad: return v * 200 / .pi
        case .rad:  return v
        }
    }

    /// Ramène à 0 les résidus d'arrondi (ex. sin 180° = 1,2e-16).
    private static func snap(_ v: Double) -> Double {
        Swift.abs(v) < 1e-15 ? 0 : v
    }

    private static func roundToDisplay(_ v: Double, _ f: DisplayFormat, _ n: Int) -> Double {
        let d = format(v, f, n)
        var s = d.mantissa
        if let e = d.exponent { s += "e" + e }
        return Double(s) ?? v
    }

    // MARK: Formatage (10 chiffres maximum, comme la HP-11C)

    static func format(_ v: Double, _ f: DisplayFormat, _ n: Int) -> DisplayText {
        guard v.isFinite else { return DisplayText(mantissa: v.isNaN ? "NaN" : (v < 0 ? "-∞" : "∞"), exponent: nil) }
        switch f {
        case .fix: return formatFix(v, n)
        case .sci: return formatSci(v, n)
        case .eng: return formatEng(v, n)
        }
    }

    private static func formatFix(_ v: Double, _ n: Int) -> DisplayText {
        let a = Swift.abs(v)
        if a >= 1e10 { return formatSci(v, n) }
        let intDigits = a < 1 ? 1 : Int(floor(log10(a))) + 1
        let decimals = max(0, min(n, 10 - intDigits))
        let s = String(format: "%.\(decimals)f", v)
        let parsed = Double(s) ?? 0
        // Trop petit pour FIX (s'afficherait 0) ou débordement après arrondi : passage en SCI.
        if (parsed == 0 && v != 0) || Swift.abs(parsed) >= 1e10 {
            return formatSci(v, n)
        }
        return DisplayText(mantissa: s, exponent: nil)
    }

    private static func splitSci(_ v: Double, _ digits: Int) -> (String, Int) {
        let s = String(format: "%.\(digits)e", v)
        let parts = s.split(separator: "e")
        let exp = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return (String(parts[0]), exp)
    }

    private static func exponentString(_ e: Int) -> String {
        (e < 0 ? "-" : "") + String(format: "%02d", Swift.abs(e))
    }

    private static func formatSci(_ v: Double, _ n: Int) -> DisplayText {
        let (m, e) = splitSci(v, min(n, 9))
        return DisplayText(mantissa: m, exponent: exponentString(e))
    }

    private static func formatEng(_ v: Double, _ n: Int) -> DisplayText {
        let digits = min(n, 9)
        let (m, e) = splitSci(v, digits)
        let e3 = Int(floor(Double(e) / 3)) * 3
        let shift = e - e3
        let mv = (Double(m) ?? 0) * pow(10, Double(shift))
        let decimals = max(digits - shift, 0)
        return DisplayText(mantissa: String(format: "%.\(decimals)f", mv), exponent: exponentString(e3))
    }
}
