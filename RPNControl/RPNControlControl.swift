import AppIntents
import SwiftUI
import WidgetKit

/// Bouton du Centre de contrôle (iOS 18+) qui ouvre la calculatrice.
struct RPNControlControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "Brohuld-Diving.Brohuld-s-Dive-Log.RPNControl") {
            ControlWidgetButton(action: OpenCalculatorIntent()) {
                Label("RPN Calculator", image: "rpn.calculator")  // symbole personnalisé (Assets.xcassets)
            }
        }
        .displayName("RPN Calculator")
        .description("Open the RPN calculator.")
    }
}
