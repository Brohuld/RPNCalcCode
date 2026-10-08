import SwiftUI

@main
struct RPNCalcApp: App {
    @State private var model = CalculatorModel()

    var body: some Scene {
        WindowGroup {
            CalculatorView(model: model)
                #if os(macOS)
                .frame(minWidth: 460, idealWidth: 480, minHeight: 900, idealHeight: 920)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 920)
        #endif
    }
}
