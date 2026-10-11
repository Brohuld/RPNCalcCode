import AppIntents

/// Action « ouvrir la calculatrice », utilisée par le bouton du Centre de contrôle.
/// Ce fichier appartient à la fois à l'app et à l'extension RPNControl :
/// c'est ce qui permet au bouton d'ouvrir réellement l'app.
enum CalculatorScreen: String, AppEnum {
    case calculator

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Calculator"
    static let caseDisplayRepresentations: [CalculatorScreen: DisplayRepresentation] = [
        .calculator: "RPN Calculator",
    ]
}

struct OpenCalculatorIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open RPN Calculator"

    @Parameter(title: "Screen")
    var target: CalculatorScreen

    init() {
        target = .calculator
    }
}
