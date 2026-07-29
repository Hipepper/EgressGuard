import Foundation
import Testing
@testable import EgressGuard

@Suite("Domain models")
struct DomainModelTests {
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

    @Test("PRD defaults are preserved")
    func settingsDefaults() {
        #expect(GuardSettings.defaults.checkInterval == 30)
        #expect(GuardSettings.defaults.requestTimeout == 5)
        #expect(GuardSettings.defaults.violationThreshold == 3)
        #expect(GuardSettings.defaults.recoveryThreshold == 2)
        #expect(GuardSettings.defaults.isProtectionEnabled == false)
        #expect(GuardSettings.defaults.menuBarIPDisplayMode == .iconOnly)
        #expect(GuardSettings.defaults.showsCountryFlagInMenuBar == false)
    }

    @Test("New protection rules are inserted at the top")
    func newRulesAreNewestFirst() {
        var settings = GuardSettings.defaults
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
        #expect(settings.showsCountryFlagInMenuBar == false)
        #expect(settings.rules.count == 1)
        #expect(settings.rules.first?.condition == .country)
        #expect(settings.rules.first?.value == "SG")
    }
}
