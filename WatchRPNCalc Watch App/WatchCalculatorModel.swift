import Foundation
import Observation

/// Version Apple Watch : même moteur RPN, limité à la saisie et aux 4 opérations.
@Observable
final class WatchCalculatorModel {
    private static let storageKey = "WatchRPNEngineState"

    private(set) var engine: RPNEngine
    /// Incrémenté à chaque touche : déclenche le retour haptique.
    private(set) var keyPressCount = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(RPNEngine.self, from: data) {
            engine = saved
        } else {
            engine = RPNEngine()
        }
    }

    func press(_ key: Key) {
        keyPressCount += 1
        engine.press(key)
        if let data = try? JSONEncoder().encode(engine) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
