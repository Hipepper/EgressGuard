import SwiftUI

@main
struct EgressGuardApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Label(model.menuBarTitle, systemImage: model.status.symbolName)
                .task { model.startMonitoring() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 780, minHeight: 560)
        }
    }
}
