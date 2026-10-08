import SwiftUI

enum KeyAction: Equatable {
    case key(Key)
    case shift
}

enum KeyStyle {
    case function, digit, operation, enter, shift
}

/// Une touche du clavier : fonction principale et fonction "2nd" optionnelle.
struct KeyDefinition: Identifiable {
    let label: String
    let primary: KeyAction
    /// nil : on lit simplement l'étiquette (chiffres).
    var accessibilityName: LocalizedStringResource?
    var secondaryLabel: String?
    var secondary: KeyAction?
    var secondaryAccessibilityName: LocalizedStringResource?
    var style: KeyStyle = .function
    var columns: Int = 1

    var id: String { label }

    func action(shifted: Bool) -> KeyAction {
        if shifted, let secondary { return secondary }
        return primary
    }

    func displayedLabel(shifted: Bool) -> String {
        if shifted, let secondaryLabel { return secondaryLabel }
        return label
    }

    func displayedAccessibilityName(shifted: Bool) -> LocalizedStringResource? {
        if shifted, let secondaryAccessibilityName { return secondaryAccessibilityName }
        return accessibilityName
    }
}

enum Keypad {
    private static func digit(_ n: Int) -> KeyDefinition {
        KeyDefinition(label: String(n), primary: .key(.digit(n)), style: .digit)
    }

    /// Bloc scientifique : 3 rangées de 5 touches.
    static let functionRows: [[KeyDefinition]] = [
        [
            KeyDefinition(label: "2nd", primary: .shift, accessibilityName: "Second function", style: .shift),
            KeyDefinition(label: "x⇄y", primary: .key(.swapXY), accessibilityName: "Swap X and Y",
                          secondaryLabel: "R↑", secondary: .key(.rollUp), secondaryAccessibilityName: "Roll up"),
            KeyDefinition(label: "R↓", primary: .key(.rollDown), accessibilityName: "Roll down",
                          secondaryLabel: "CLR", secondary: .key(.clearStack), secondaryAccessibilityName: "Clear stack"),
            KeyDefinition(label: "STO", primary: .key(.sto), accessibilityName: "Store",
                          secondaryLabel: "RND", secondary: .key(.round), secondaryAccessibilityName: "Round"),
            KeyDefinition(label: "RCL", primary: .key(.rcl), accessibilityName: "Recall",
                          secondaryLabel: "CLRG", secondary: .key(.clearRegisters), secondaryAccessibilityName: "Clear registers"),
        ],
        [
            KeyDefinition(label: "sin", primary: .key(.sin), accessibilityName: "Sine",
                          secondaryLabel: "sin⁻¹", secondary: .key(.asin), secondaryAccessibilityName: "Arc sine"),
            KeyDefinition(label: "cos", primary: .key(.cos), accessibilityName: "Cosine",
                          secondaryLabel: "cos⁻¹", secondary: .key(.acos), secondaryAccessibilityName: "Arc cosine"),
            KeyDefinition(label: "tan", primary: .key(.tan), accessibilityName: "Tangent",
                          secondaryLabel: "tan⁻¹", secondary: .key(.atan), secondaryAccessibilityName: "Arc tangent"),
            KeyDefinition(label: "ln", primary: .key(.ln), accessibilityName: "Natural logarithm",
                          secondaryLabel: "eˣ", secondary: .key(.exp), secondaryAccessibilityName: "Exponential"),
            KeyDefinition(label: "log", primary: .key(.log), accessibilityName: "Common logarithm",
                          secondaryLabel: "10ˣ", secondary: .key(.exp10), secondaryAccessibilityName: "Ten to the power of X"),
        ],
        [
            KeyDefinition(label: "√x", primary: .key(.sqrt), accessibilityName: "Square root",
                          secondaryLabel: "x²", secondary: .key(.square), secondaryAccessibilityName: "Square"),
            KeyDefinition(label: "yˣ", primary: .key(.power), accessibilityName: "Power",
                          secondaryLabel: "ˣ√y", secondary: .key(.root), secondaryAccessibilityName: "Root"),
            KeyDefinition(label: "1/x", primary: .key(.reciprocal), accessibilityName: "Reciprocal",
                          secondaryLabel: "x!", secondary: .key(.factorial), secondaryAccessibilityName: "Factorial"),
            KeyDefinition(label: "%", primary: .key(.percent), accessibilityName: "Percent",
                          secondaryLabel: "Δ%", secondary: .key(.deltaPercent), secondaryAccessibilityName: "Percent change"),
            KeyDefinition(label: "INT", primary: .key(.intPart), accessibilityName: "Integer part",
                          secondaryLabel: "FRAC", secondary: .key(.fracPart), secondaryAccessibilityName: "Fractional part"),
        ],
    ]

    /// Paysage : les 15 fonctions + CHS, EEX, ← réparties sur 2 rangées de 9.
    static var landscapeFunctionRows: [[KeyDefinition]] {
        let top = functionRows[0] + functionRows[2].prefix(4)
        let bottom = functionRows[1] + functionRows[2].suffix(1) + editRow
        return [Array(top), Array(bottom)]
    }

    /// ENTER : seule sur sa rangée, sur toute la largeur.
    static let enterKey = KeyDefinition(label: "ENTER", primary: .key(.enter), accessibilityName: "Enter",
                                        secondaryLabel: "LSTx", secondary: .key(.lastX), secondaryAccessibilityName: "Last X",
                                        style: .enter)

    /// Rangée d'édition : 3 touches de même largeur.
    static let editRow: [KeyDefinition] = [
        KeyDefinition(label: "CHS", primary: .key(.chs), accessibilityName: "Change sign",
                      secondaryLabel: "ABS", secondary: .key(.abs), secondaryAccessibilityName: "Absolute value"),
        KeyDefinition(label: "EEX", primary: .key(.eex), accessibilityName: "Exponent",
                      secondaryLabel: "π", secondary: .key(.pi), secondaryAccessibilityName: "Pi"),
        KeyDefinition(label: "←", primary: .key(.backspace), accessibilityName: "Delete",
                      secondaryLabel: "CLx", secondary: .key(.clx), secondaryAccessibilityName: "Clear X"),
    ]

    /// Pavé numérique : 4 rangées de 4 colonnes (0 occupe 2 colonnes).
    static func numberRows(decimalSeparator: String) -> [[KeyDefinition]] {
        [
            [digit(7), digit(8), digit(9),
             KeyDefinition(label: "÷", primary: .key(.divide), accessibilityName: "Divide", style: .operation)],
            [digit(4), digit(5), digit(6),
             KeyDefinition(label: "×", primary: .key(.multiply), accessibilityName: "Multiply", style: .operation)],
            [digit(1), digit(2), digit(3),
             KeyDefinition(label: "−", primary: .key(.subtract), accessibilityName: "Subtract", style: .operation)],
            [
                KeyDefinition(label: "0", primary: .key(.digit(0)), style: .digit, columns: 2),
                KeyDefinition(label: decimalSeparator, primary: .key(.point), accessibilityName: "Decimal point", style: .digit),
                KeyDefinition(label: "+", primary: .key(.add), accessibilityName: "Add", style: .operation),
            ],
        ]
    }
}
