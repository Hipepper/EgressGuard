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
    }
}
