import Foundation
import Observation

/// Fait le lien entre le moteur RPN et l'interface (touche "2nd", sauvegarde).
@Observable
final class CalculatorModel {
    private static let storageKey = "RPNEngineState"

    private(set) var engine: RPNEngine
    var shiftActive = false
    /// Incrémenté à chaque touche : sert de déclencheur au retour haptique.
    private(set) var keyPressCount = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(RPNEngine.self, from: data) {
            engine = saved
        } else {
            engine = RPNEngine()
        }
    }

    func press(_ keyDef: KeyDefinition) {
        keyPressCount += 1
        switch keyDef.action(shifted: shiftActive) {
        case .shift:
            shiftActive.toggle()
            return
        case .key(let key):
            shiftActive = false
            engine.press(key)
        }
        save()
    }

    /// Touche issue du clavier physique (pas de "2nd").
    func press(_ key: Key) {
        keyPressCount += 1
        shiftActive = false
        engine.press(key)
        save()
    }

    /// Colle un nombre depuis le presse-papiers. Renvoie false si le texte n'est pas un nombre.
    @discardableResult
    func paste(_ text: String?) -> Bool {
        guard let text, let value = RPNEngine.parseNumber(text) else { return false }
        keyPressCount += 1
        shiftActive = false
        engine.enterValue(value)
        save()
        return true
    }

    var angleMode: AngleMode {
        get { engine.angleMode }
        set { engine.angleMode = newValue; save() }
    }

    var displayFormat: DisplayFormat {
        get { engine.displayFormat }
        set { engine.displayFormat = newValue; save() }
    }

    var displayDigits: Int {
        get { engine.displayDigits }
        set { engine.displayDigits = newValue; save() }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(engine) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
