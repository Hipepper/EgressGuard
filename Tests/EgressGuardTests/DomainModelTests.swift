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
    }
}
