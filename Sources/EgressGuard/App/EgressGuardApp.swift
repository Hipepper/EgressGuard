import SwiftUI

@main
struct EgressGuardApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.status.symbolName)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 16, height: 16)
                if let menuBarText = model.menuBarText {
                    Text(menuBarText)
                }
            }
                .task { model.startMonitoring() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 980, idealWidth: 1120, minHeight: 680, idealHeight: 760)
        }
    }
}
