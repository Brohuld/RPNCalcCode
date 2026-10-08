import SwiftUI

/// Une touche de la montre.
private struct WatchKey: Identifiable {
    enum Style { case digit, operation, enter }

    let label: String
    let key: Key
    var style: Style = .digit
    var accessibilityName: LocalizedStringResource?
    var columns: Int = 1

    var id: String { label }
}

struct ContentView: View {
    var model: WatchCalculatorModel

    private let decimalSeparator = Locale.current.decimalSeparator ?? "."
    private let spacing: CGFloat = 2

    private var rows: [[WatchKey]] {
        [
            [digit(7), digit(8), digit(9),
             WatchKey(label: "÷", key: .divide, style: .operation, accessibilityName: "Divide")],
            [digit(4), digit(5), digit(6),
             WatchKey(label: "×", key: .multiply, style: .operation, accessibilityName: "Multiply")],
            [digit(1), digit(2), digit(3),
             WatchKey(label: "−", key: .subtract, style: .operation, accessibilityName: "Subtract")],
            [digit(0),
             WatchKey(label: decimalSeparator, key: .point, accessibilityName: "Decimal point"),
             WatchKey(label: "←", key: .backspace, accessibilityName: "Delete"),
             WatchKey(label: "+", key: .add, style: .operation, accessibilityName: "Add")],
        ]
    }

    private let enterKey = WatchKey(label: "ENTER", key: .enter, style: .enter, accessibilityName: "Enter")

    private func digit(_ n: Int) -> WatchKey {
        WatchKey(label: String(n), key: .digit(n))
    }

    var body: some View {
        VStack(spacing: spacing) {
            display
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(rows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(rows[r]) { key in
                            keyButton(key)
                        }
                    }
                }
                // ENTER sur toute la largeur, même hauteur que les autres rangées.
                GridRow {
                    keyButton(enterKey)
                        .gridCellColumns(4)
                }
            }
        }
        // Utilise aussi la bande du bas réservée par le système (ENTER, large, s'accommode des coins arrondis).
        .ignoresSafeArea(edges: .bottom)
        // Remonte le contenu sous la barre de l'heure.
        .padding(.top, -6)
        .sensoryFeedback(.impact(weight: .light), trigger: model.keyPressCount)
    }

    // MARK: Afficheur (Y en petit, X en grand)

    private var display: some View {
        // Une seule ligne : Y en petit à gauche, X à droite.
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            numberText(model.engine.display(model.engine.y), size: 10)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 50, alignment: .leading)
            Spacer(minLength: 0)
            if let error = model.engine.error {
                Text(error == .overflow ? LocalizedStringKey("Overflow") : LocalizedStringKey("Math error"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                numberText(model.engine.xDisplay, size: 20)
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 24)
        .background(Color(white: 0.86), in: RoundedRectangle(cornerRadius: 6))
        .environment(\.colorScheme, .light)
    }

    private func numberText(_ d: DisplayText, size: CGFloat) -> some View {
        var text = Text(verbatim: d.mantissa.replacingOccurrences(of: ".", with: decimalSeparator))
            .font(.system(size: size, weight: .regular, design: .rounded))
        if let e = d.exponent {
            text = text
                + Text(verbatim: " ×10")
                    .font(.system(size: size * 0.5, design: .rounded))
                + Text(verbatim: e)
                    .font(.system(size: size * 0.45, design: .rounded))
                    .baselineOffset(size * 0.4)
        }
        return text
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    // MARK: Touches

    private func keyButton(_ key: WatchKey) -> some View {
        Button {
            model.press(key.key)
        } label: {
            Text(verbatim: key.label)
                .font(.system(size: key.style == .enter ? 16 : 24, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.white)
                .background(background(key.style), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(key))
    }

    private func background(_ style: WatchKey.Style) -> Color {
        switch style {
        case .digit: return Color.white.opacity(0.14)
        case .operation: return Color(red: 1.0, green: 0.58, blue: 0.0)
        case .enter: return Color(red: 0.80, green: 0.36, blue: 0.0)
        }
    }

    private func accessibilityText(_ key: WatchKey) -> Text {
        if let name = key.accessibilityName { return Text(name) }
        return Text(verbatim: key.label)
    }
}

#Preview {
    ContentView(model: WatchCalculatorModel())
}
