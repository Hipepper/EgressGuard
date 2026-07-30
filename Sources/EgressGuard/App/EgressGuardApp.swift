import AppKit
import SwiftUI

@main
struct EgressGuardApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
                .preferredColorScheme(model.settings.interfaceTheme.colorScheme)
                .id(model.settings.interfaceTheme)
        } label: {
            HStack(alignment: .center, spacing: 4) {
                if model.showsMenuBarActivityIndicator {
                    MenuBarActivityIndicator()
                } else {
                    if model.showsMenuBarStatusIcon {
                        Image(systemName: model.status.menuBarSymbolName)
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(model.status.color)
                            .frame(width: 17, height: 17, alignment: .center)
                    }
                    if let menuBarText = model.menuBarText {
                        Text(menuBarText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .fixedSize()
                    }
                }
            }
                .frame(height: 20, alignment: .center)
                .task { model.startMonitoring() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 980, idealWidth: 1120, minHeight: 680, idealHeight: 760)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
        }
    }
}

private struct MenuBarActivityIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .symbolEffect(
                .variableColor.iterative.reversing,
                options: .repeating,
                isActive: !reduceMotion
            )
            .frame(width: 24, height: 17)
        .accessibilityLabel("正在检测出口 IP")
    }
}
