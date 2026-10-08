import SwiftUI

@main
struct WatchRPNCalcApp: App {
    @State private var model = WatchCalculatorModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
