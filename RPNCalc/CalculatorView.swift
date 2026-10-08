import SwiftUI
import UniformTypeIdentifiers

/// Facteur d'agrandissement global : tout est 25 % plus grand sur Mac.
enum Metrics {
    static let scale: CGFloat = {
        #if os(macOS)
        return 1.25
        #else
        return 1
        #endif
    }()
}

struct CalculatorView: View {
    @Bindable var model: CalculatorModel
    @FocusState private var keyboardFocused: Bool

    private let decimalSeparator = Locale.current.decimalSeparator ?? "."
    private let spacing: CGFloat = 8 * Metrics.scale

    var body: some View {
        GeometryReader { geo in
            Group {
                if geo.size.width > geo.size.height {
                    // Paysage : afficheur à gauche, clavier à droite.
                    HStack(alignment: .top, spacing: 16 * Metrics.scale) {
                        VStack(spacing: 12 * Metrics.scale) {
                            statusBar
                            display
                            Spacer(minLength: 0)
                        }
                        .frame(width: max(260, geo.size.width * 0.36))
                        landscapeKeypad(enterWidth: max(90, geo.size.width * 0.12),
                                        rowHeight: max(34, (geo.size.height - 32 - 5 * spacing) / 6))
                    }
                } else {
                    // Portrait : afficheur en haut, clavier en dessous.
                    VStack(spacing: 12 * Metrics.scale) {
                        statusBar
                        display
                        portraitKeypad
                    }
                    .frame(maxWidth: isPad ? .infinity : 560 * Metrics.scale)
                }
            }
            .padding(16 * Metrics.scale)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.calcBackground.ignoresSafeArea())
        .focusable()
        .focused($keyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down, action: handleKeyPress)
        #if os(macOS)
        .onCopyCommand {
            [NSItemProvider(object: plainText(model.engine.xDisplay) as NSString)]
        }
        .onPasteCommand(of: [.plainText]) { _ in
            pasteX()
        }
        #endif
        .onAppear { keyboardFocused = true }
        #if os(iOS)
        .sensoryFeedback(.impact(weight: .light), trigger: model.keyPressCount)
        #endif
    }

    // MARK: Barre d'état

    private var statusBar: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Angle", selection: $model.angleMode) {
                    Text("Degrees").tag(AngleMode.deg)
                    Text("Radians").tag(AngleMode.rad)
                    Text("Grads").tag(AngleMode.grad)
                }
            } label: {
                StatusChip(text: model.angleMode.shortLabel)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()

            Menu {
                Picker("Display", selection: $model.displayFormat) {
                    Text("Fixed").tag(DisplayFormat.fix)
                    Text("Scientific").tag(DisplayFormat.sci)
                    Text("Engineering").tag(DisplayFormat.eng)
                }
                Picker("Digits", selection: $model.displayDigits) {
                    ForEach(0..<10) { n in
                        Text(verbatim: String(n)).tag(n)
                    }
                }
            } label: {
                StatusChip(text: "\(model.displayFormat.shortLabel) \(model.displayDigits)")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer()

            Button(action: copyX) {
                IconChip(systemName: "doc.on.doc")
            }
            .accessibilityLabel(Text("Copy"))

            Button(action: pasteX) {
                IconChip(systemName: "doc.on.clipboard")
            }
            .accessibilityLabel(Text("Paste"))

            if let pending = model.engine.pending {
                StatusChip(text: pending == .store ? "STO" : "RCL", highlighted: true)
            }
            if model.shiftActive {
                StatusChip(text: "2nd", highlighted: true)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Afficheur

    /// Afficheur agrandi sur iPad.
    private var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 4) {
            stackRow("T", model.engine.t)
            stackRow("Z", model.engine.z)
            stackRow("Y", model.engine.y)
            xRow
        }
        .padding(.horizontal, 16 * Metrics.scale)
        .padding(.vertical, 12 * Metrics.scale)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(Color.displayBackground, in: RoundedRectangle(cornerRadius: 16 * Metrics.scale))
        // Afficheur toujours en noir sur gris clair, même en mode sombre.
        .environment(\.colorScheme, .light)
        .contextMenu {
            Button("Copy", action: copyX)
            Button("Paste", action: pasteX)
        }
    }

    private func stackRow(_ name: String, _ value: Double) -> some View {
        HStack {
            Text(verbatim: name)
                .font(isPad ? Font.body.weight(.semibold) : .system(size: 12 * Metrics.scale, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            numberText(model.engine.display(value), size: isPad ? 32 : 20 * Metrics.scale)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var xRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: "X")
                .font(isPad ? Font.body.weight(.semibold) : .system(size: 12 * Metrics.scale, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let error = model.engine.error {
                Text(error.message)
                    .font(.system(size: isPad ? 48 : 30 * Metrics.scale, weight: .regular, design: .rounded))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                numberText(model.engine.xDisplay, size: isPad ? 80 : 48 * Metrics.scale)
            }
        }
        .frame(minHeight: isPad ? 96 : 60 * Metrics.scale)
        .accessibilityElement(children: .combine)
    }

    private func numberText(_ d: DisplayText, size: CGFloat) -> some View {
        var text = Text(verbatim: localized(d.mantissa))
            .font(.system(size: size, weight: .light, design: .rounded))
        if let e = d.exponent {
            text = text
                + Text(verbatim: " ×10")
                    .font(.system(size: size * 0.5, weight: .light, design: .rounded))
                + Text(verbatim: e)
                    .font(.system(size: size * 0.45, weight: .regular, design: .rounded))
                    .baselineOffset(size * 0.4)
        }
        return text
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.3)
    }

    private func localized(_ s: String) -> String {
        s.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    private func copyX() {
        Clipboard.copy(plainText(model.engine.xDisplay))
    }

    private func pasteX() {
        model.paste(Clipboard.string())
    }

    private func plainText(_ d: DisplayText) -> String {
        var s = localized(d.mantissa)
        if let e = d.exponent { s += "E" + e }
        return s
    }

    // MARK: Clavier

    private let functionKeyHeight: CGFloat = 44 * Metrics.scale
    private var enterKeyHeight: CGFloat { isPad ? 110 : 60 * Metrics.scale }

    /// Portrait : touches de fonction compactes (hauteur fixe), pavé numérique extensible.
    private var portraitKeypad: some View {
        VStack(spacing: spacing) {
            functionGrid(fixedHeight: true)
            editRow(fixedHeight: true)
            enterButton(fixedHeight: true)
            numberGrid
        }
    }

    /// Paysage : toutes les fonctions en haut (2 rangées de 9),
    /// en dessous le pavé numérique et un grand ENTER à droite.
    private func landscapeKeypad(enterWidth: CGFloat, rowHeight: CGFloat) -> some View {
        VStack(spacing: spacing) {
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(Keypad.landscapeFunctionRows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(Keypad.landscapeFunctionRows[r]) { key in
                            keyButton(key)
                                .frame(height: rowHeight)
                        }
                    }
                }
            }
            HStack(spacing: spacing) {
                numberGrid
                keyButton(Keypad.enterKey)
                    .frame(width: enterWidth)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func functionGrid(fixedHeight: Bool) -> some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(Keypad.functionRows.indices, id: \.self) { r in
                GridRow {
                    ForEach(Keypad.functionRows[r]) { key in
                        keyButton(key)
                            .frame(height: fixedHeight ? functionKeyHeight : nil)
                    }
                }
            }
        }
    }

    private func editRow(fixedHeight: Bool) -> some View {
        HStack(spacing: spacing) {
            ForEach(Keypad.editRow) { key in
                keyButton(key)
            }
        }
        .frame(height: fixedHeight ? functionKeyHeight : nil)
    }

    private func enterButton(fixedHeight: Bool) -> some View {
        keyButton(Keypad.enterKey)
            .frame(height: fixedHeight ? enterKeyHeight : nil)
    }

    private var numberGrid: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            let rows = Keypad.numberRows(decimalSeparator: decimalSeparator)
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r]) { key in
                        keyButton(key)
                            .gridCellColumns(key.columns)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: KeyDefinition) -> some View {
        let shifted = model.shiftActive
        return Button {
            model.press(key)
        } label: {
            KeyLabel(key: key, shifted: shifted)
        }
        .buttonStyle(CalcKeyStyle(style: key.style, active: key.primary == .shift && shifted))
        .accessibilityLabel(accessibilityText(key, shifted: shifted))
    }

    private func accessibilityText(_ key: KeyDefinition, shifted: Bool) -> Text {
        if let name = key.displayedAccessibilityName(shifted: shifted) {
            return Text(name)
        }
        return Text(verbatim: key.displayedLabel(shifted: shifted))
    }

    // MARK: Clavier physique (Mac, iPad avec clavier)

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            #if os(iOS)
            switch press.characters.lowercased() {
            case "c": copyX(); return .handled
            case "v": pasteX(); return .handled
            default: break
            }
            #endif
            return .ignored
        }
        // Entrée du pavé numérique : caractère ETX (U+0003) sur Mac, en plus de Retour.
        let numericPadEnter = KeyEquivalent("\u{03}")
        if press.key == numericPadEnter || press.characters == "\u{03}" {
            model.press(.enter); return .handled
        }
        switch press.key {
        case .return:
            model.press(.enter); return .handled
        case .delete, .deleteForward:
            model.press(.backspace); return .handled
        case .escape:
            model.press(.clx); return .handled
        default:
            break
        }
        let mapping: [String: Key] = [
            "+": .add, "-": .subtract, "*": .multiply, "/": .divide,
            ".": .point, ",": .point, "e": .eex, "E": .eex,
            "n": .chs, "^": .power, "s": .swapXY, "r": .rollDown,
        ]
        if let ch = press.characters.first, let d = ch.wholeNumberValue, ch.isASCII {
            model.press(.digit(d)); return .handled
        }
        if let key = mapping[press.characters] {
            model.press(key); return .handled
        }
        return .ignored
    }
}

// MARK: - Éléments visuels

private struct StatusChip: View {
    let text: String
    var highlighted = false

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 12 * Metrics.scale, weight: .semibold).monospaced())
            .padding(.horizontal, 10 * Metrics.scale)
            .padding(.vertical, 5 * Metrics.scale)
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .background(highlighted ? Color.accentColor : Color.primary.opacity(0.08), in: Capsule())
    }
}

private struct IconChip: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12 * Metrics.scale, weight: .semibold))
            .frame(width: 34 * Metrics.scale, height: 24 * Metrics.scale)
            .foregroundStyle(Color.primary)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .contentShape(Capsule())
    }
}

private struct KeyLabel: View {
    let key: KeyDefinition
    let shifted: Bool

    var body: some View {
        VStack(spacing: 1) {
            // Fonction secondaire en petit au-dessus (ou principale quand "2nd" est actif).
            Text(verbatim: smallLabel ?? " ")
                .font(.system(size: smallFontSize, weight: .medium))
                .foregroundStyle(smallLabelColor)
                .opacity(smallLabel == nil ? 0 : 1)
            Text(verbatim: key.displayedLabel(shifted: shifted))
                .font(.system(size: mainFontSize, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    /// Touches de fonction en police plus petite sur iPhone.
    private var isPhoneFunctionKey: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
            && (key.style == .function || key.style == .shift)
        #else
        return false
        #endif
    }

    /// Chiffres et opérations en grand sur iPad.
    private var isPadNumberKey: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
            && (key.style == .digit || key.style == .operation)
        #else
        return false
        #endif
    }

    private var mainFontSize: CGFloat {
        if isPadNumberKey { return 34 }
        return isPhoneFunctionKey ? 15 : 18 * Metrics.scale
    }
    private var smallFontSize: CGFloat { isPhoneFunctionKey ? 9 : 10 * Metrics.scale }

    /// Sur fond coloré (ENTER), l'orange serait invisible : blanc atténué.
    private var smallLabelColor: Color {
        switch key.style {
        case .enter, .operation: return Color.white.opacity(0.8)
        default: return Color.accentColor
        }
    }

    private var smallLabel: String? {
        guard let secondary = key.secondaryLabel else { return nil }
        return shifted ? key.label : secondary
    }
}

private struct CalcKeyStyle: ButtonStyle {
    let style: KeyStyle
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(minHeight: 40 * Metrics.scale)
            .background(background, in: RoundedRectangle(cornerRadius: 12 * Metrics.scale))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch style {
        case .operation, .enter: return .white
        case .shift: return active ? .white : .accentColor
        default: return .primary
        }
    }

    private var background: Color {
        switch style {
        case .function: return Color.primary.opacity(0.10)
        case .digit: return Color.primary.opacity(0.05)
        case .operation: return .accentColor
        case .enter: return .enterKey
        case .shift: return active ? .accentColor : Color.accentColor.opacity(0.15)
        }
    }
}

// MARK: - Couleurs et libellés

private extension Color {
    static let enterKey = Color(red: 0.80, green: 0.36, blue: 0.0)
    static let calcBackground = Color.primary.opacity(0.03)
    static let displayBackground = Color(white: 0.86)
}

extension AngleMode {
    var shortLabel: String {
        switch self {
        case .deg: return "DEG"
        case .rad: return "RAD"
        case .grad: return "GRAD"
        }
    }
}

extension DisplayFormat {
    var shortLabel: String {
        switch self {
        case .fix: return "FIX"
        case .sci: return "SCI"
        case .eng: return "ENG"
        }
    }
}

extension CalcError {
    var message: LocalizedStringResource {
        switch self {
        case .math: return "Math error"
        case .overflow: return "Overflow"
        }
    }
}

#Preview {
    CalculatorView(model: CalculatorModel())
}
