import Foundation
import Testing
@testable import EgressGuard

@Suite("Domain models")
struct DomainModelTests {
    @Test("Menu bar uses a filled shield for healthy protection")
    func healthyMenuBarStatusAppearance() {
        #expect(GuardDisplayStatus.healthy.menuBarSymbolName == "checkmark.shield.fill")
        #expect(GuardDisplayStatus.violation.menuBarSymbolName == "exclamationmark.shield.fill")
    }

    @Test("Checking replaces hidden shield and IP text with activity indicator")
    func checkingUsesMenuBarActivityIndicator() {
        #expect(GuardDisplayStatus.checking.showsMenuBarActivityIndicator(statusIconPreference: false))
        #expect(!GuardDisplayStatus.checking.showsMenuBarActivityIndicator(statusIconPreference: true))
        #expect(!GuardDisplayStatus.healthy.showsMenuBarActivityIndicator(statusIconPreference: false))
    }

    @Test("Application catalog includes closed apps and marks running apps")
    func applicationCatalogMerge() {
        let installed = [
            InstalledApplication(
                bundleIdentifier: "com.example.closed",
                displayName: "Closed App",
                url: URL(fileURLWithPath: "/Applications/Closed.app"),
                isRunning: false
            ),
            InstalledApplication(
                bundleIdentifier: "com.example.running",
                displayName: "Running App",
                url: URL(fileURLWithPath: "/Applications/Running.app"),
                isRunning: false
            )
        ]
        let running = [
            InstalledApplication(
                bundleIdentifier: "com.example.running",
                displayName: "Running App",
                url: URL(fileURLWithPath: "/Applications/Running.app"),
                isRunning: true
            )
        ]

        let applications = ApplicationCatalog.merging(installed: installed, running: running)

        #expect(applications.count == 2)
        #expect(applications.first { $0.bundleIdentifier == "com.example.closed" }?.isRunning == false)
        #expect(applications.first { $0.bundleIdentifier == "com.example.running" }?.isRunning == true)
    }

    @Test("Country code becomes a flag")
    func countryFlag() {
        let identity = ExitIdentity(
            ip: "203.0.113.10",
            countryCode: "SG",
            countryName: "Singapore",
            asn: "AS64500",
            organization: nil,
            provider: "mock",
            checkedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(identity.countryFlag == "🇸🇬")
    }

    @Test("Unknown country uses globe")
    func unknownCountryFlag() {
        let identity = ExitIdentity(
            ip: "2001:db8::1",
            countryCode: nil,
            countryName: nil,
            asn: nil,
            organization: nil,
            provider: "mock",
            checkedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(identity.countryFlag == "🌐")
    }

    @Test("Region picker replaces non-country flags with a placeholder")
    func regionFlagPlaceholder() {
        #expect(RegionFlag.symbol(for: "SG") == "🇸🇬")
        #expect(RegionFlag.symbol(for: "002") == "--")
        #expect(RegionFlag.symbol(for: "") == "--")
    }

    @Test("PRD defaults are preserved")
    func settingsDefaults() {
        #expect(GuardSettings.defaults.checkInterval == 30)
        #expect(GuardSettings.defaults.requestTimeout == 5)
        #expect(GuardSettings.defaults.violationThreshold == 3)
        #expect(GuardSettings.defaults.recoveryThreshold == 2)
        #expect(GuardSettings.defaults.isProtectionEnabled == false)
        #expect(GuardSettings.defaults.menuBarIPDisplayMode == .iconOnly)
        #expect(GuardSettings.defaults.showsStatusIconInMenuBar == true)
        #expect(GuardSettings.defaults.showsCountryFlagInMenuBar == false)
        #expect(GuardSettings.defaults.checkIntervalUnit == .seconds)
        #expect(GuardSettings.defaults.menuBarCountryDisplayMode == .hidden)
        #expect(GuardSettings.defaults.interfaceTheme == .system)
        #expect(GuardSettings.defaults.rules.count == 3)
        #expect(GuardSettings.defaults.rules.allSatisfy { !$0.isEnabled })
        #expect(GuardSettings.defaults.rules.map(\.condition) == [.ip, .cidr, .country])
        #expect(GuardSettings.defaults.rules.map(\.value) == ["203.0.113.10", "203.0.113.0/24", "SG"])
    }

    @Test("Settings sidebar omits the redundant protected applications page")
    func settingsSidebarSections() {
        #expect(SettingsSection.allCases.map(\.title) == ["概览", "保护规则", "本地网络", "通知", "运行日志", "设置"])
    }

    @Test("Continuous selector maps pointer positions and clamps at its edges")
    func continuousSelectionIndex() {
        #expect(ContinuousSelection.index(position: -10, totalExtent: 300, itemCount: 3) == 0)
        #expect(ContinuousSelection.index(position: 149, totalExtent: 300, itemCount: 3) == 1)
        #expect(ContinuousSelection.index(position: 400, totalExtent: 300, itemCount: 3) == 2)
        #expect(ContinuousSelection.index(position: 10, totalExtent: 0, itemCount: 3) == nil)
    }

    @Test("Settings layout keeps interactions quick and the overview compact")
    func settingsLayoutMetrics() {
        #expect(SettingsLayoutMetrics.selectionAnimationDuration <= 0.18)
        #expect(SettingsLayoutMetrics.themeCommitDelay <= 0.12)
        #expect(SettingsLayoutMetrics.localNetworkInitialLoadDelay > SettingsLayoutMetrics.selectionAnimationDuration)
        #expect(SettingsLayoutMetrics.overviewHeaderHeight == 170)
        #expect(SettingsLayoutMetrics.contentCornerRadius == 22)
    }

    @Test("Protection can enable or disable every visual rule at once")
    func batchProtectionToggle() {
        var settings = GuardSettings.defaults

        settings.setProtectionActive(true)
        #expect(settings.rules.allSatisfy { $0.isEnabled })

        settings.setProtectionActive(false)
        #expect(settings.rules.allSatisfy { !$0.isEnabled })
    }

    @Test("Refresh interval accepts user values in seconds or minutes")
    func refreshIntervalUnitConversion() {
        var settings = GuardSettings.defaults

        settings.setCheckInterval(value: 45, unit: .seconds)
        #expect(settings.checkInterval == 45)
        #expect(settings.checkIntervalValue == 45)

        settings.setCheckInterval(value: 2.5, unit: .minutes)
        #expect(settings.checkInterval == 150)
        #expect(settings.checkIntervalValue == 2.5)
        #expect(settings.checkIntervalUnit == .minutes)
    }

    @Test("Changing refresh unit preserves the user-entered value")
    func refreshUnitChangePreservesValue() {
        var settings = GuardSettings.defaults

        settings.setCheckInterval(value: 2, unit: .seconds)
        settings.setCheckIntervalUnit(.minutes)

        #expect(settings.checkIntervalValue == 2)
        #expect(settings.checkInterval == 120)
    }

    @Test("New protection rules are inserted at the top")
    func newRulesAreNewestFirst() {
        var settings = GuardSettings.defaults
        settings.rules = []
        let older = GuardRule(condition: .ip, value: "203.0.113.10")
        let newer = GuardRule(condition: .country, value: "SG")

        settings.addRule(older)
        settings.addRule(newer)

        #expect(settings.rules.map(\.id) == [newer.id, older.id])
    }

    @Test("Disabled rules do not enable protection")
    func disabledRulesAreIgnored() {
        var settings = GuardSettings.defaults
        settings.rules = [GuardRule(condition: .ip, value: "203.0.113.10", isEnabled: false)]

        #expect(settings.hasPolicyConstraints == false)
    }

    @Test("An enabled complete visual rule activates protection without the legacy master switch")
    func enabledVisualRuleActivatesProtection() {
        var settings = GuardSettings.defaults
        settings.rules = [GuardRule(
            comparison: .isEqual,
            condition: .cidr,
            value: "103.54.0.0/16",
            perspective: .proxy,
            action: .close,
            application: .init(
                bundleIdentifier: "com.example.NetNewsWire",
                displayName: "NetNewsWire",
                url: nil
            ),
            isEnabled: true
        )]

        #expect(settings.isProtectionActive == true)
    }

    @Test("Legacy settings decode with safe menu bar defaults")
    func legacySettingsDecode() throws {
        let json = #"""
        {
          "isProtectionEnabled": true,
          "checkInterval": 30,
          "requestTimeout": 5,
          "violationThreshold": 3,
          "recoveryThreshold": 2,
          "startupGracePeriod": 60,
          "allowedIPs": [],
          "allowedCIDRs": [],
          "allowedCountryCodes": ["SG"],
          "allowedASNs": []
        }
        """#

        let settings = try JSONDecoder().decode(GuardSettings.self, from: Data(json.utf8))
        #expect(settings.allowedCountryCodes == ["SG"])
        #expect(settings.menuBarIPDisplayMode == .iconOnly)
        #expect(settings.showsStatusIconInMenuBar == true)
        #expect(settings.showsCountryFlagInMenuBar == false)
        #expect(settings.checkIntervalUnit == .seconds)
        #expect(settings.menuBarCountryDisplayMode == .hidden)
        #expect(settings.rules.count == 1)
        #expect(settings.rules.first?.condition == .country)
        #expect(settings.rules.first?.value == "SG")
    }
}
