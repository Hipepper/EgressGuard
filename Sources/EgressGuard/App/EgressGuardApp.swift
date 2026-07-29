import SwiftUI

@main
struct EgressGuardApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: model.status.menuBarSymbolName)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(model.status.color)
                    .frame(width: 17, height: 17, alignment: .center)
                if let menuBarText = model.menuBarText {
                    Text(menuBarText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .fixedSize()
                }
            }
                .frame(height: 20, alignment: .center)
                .task { model.startMonitoring() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 980, idealWidth: 1120, minHeight: 680, idealHeight: 760)
        }
    }
}
