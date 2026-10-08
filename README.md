# Calculatrice RPN

Calculatrice RPN inspirée de la HP-11C, pour macOS 14+ et iOS/iPadOS 17+ (SwiftUI, une seule cible multiplateforme).

## Ouvrir
Double-cliquer sur `RPNCalc.xcodeproj` (Xcode 16 ou plus récent).

## Structure
- `RPNCalc/Engine/RPNEngine.swift` — moteur RPN (pile X/Y/Z/T, LastX, saisie, fonctions, registres 0–9, FIX/SCI/ENG)
- `RPNCalc/CalculatorModel.swift` — lien moteur ↔ interface, touche 2nd, sauvegarde automatique
- `RPNCalc/Keypad.swift` — disposition des touches
- `RPNCalc/CalculatorView.swift` — interface
- `RPNCalc/Localizable.xcstrings` — traductions EN/FR

## Clavier physique (Mac, iPad)
Chiffres, `.` ou `,`, `+ - * /`, Entrée = ENTER, Effacement = ←, Échap = CLx, `e` = EEX, `n` = CHS, `^` = yˣ, `s` = x⇄y, `r` = R↓.

## Prochaines étapes
Programmation, statistiques (Σ+), conversions →P/→R et H.MS, icône.
