import Foundation
import Testing
@testable import EgressGuard

@Suite("Settings persistence")
struct SettingsStoreTests {
    @Test("Settings and selected applications survive reload")
    func roundTrip() throws {
        let suiteName = "EgressGuardTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        var settings = GuardSettings.defaults
        settings.allowedCountryCodes = ["SG"]
        settings.isProtectionEnabled = true
        settings.setCheckInterval(value: 2, unit: .minutes)
        settings.menuBarIPDisplayMode = .abbreviatedIPv4
        settings.menuBarCountryDisplayMode = .code
        let application = ProtectedApplication(
            bundleIdentifier: "com.example.App",
            displayName: "Example",
            applicationURL: URL(fileURLWithPath: "/Applications/Example.app")
        )

        store.saveSettings(settings)
        store.saveApplications([application])

        #expect(store.loadSettings() == settings)
        #expect(store.loadApplications() == [application])
    }
}
