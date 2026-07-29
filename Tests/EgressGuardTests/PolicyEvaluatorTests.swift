import Foundation
import Testing
@testable import EgressGuard

@Suite("Policy evaluator")
struct PolicyEvaluatorTests {
    @Test("Exact IP and CIDR are OR within the IP category")
    func ipRulesAreOR() {
        let policy = policy(ips: ["198.51.100.1"], cidrs: ["203.0.113.0/24"])
        let result = PolicyEvaluator().evaluate(identity(ip: "203.0.113.255"), against: policy)
        #expect(result.decision == .allowed)
    }

    @Test("Different categories are AND")
    func categoriesAreAND() {
        let policy = policy(cidrs: ["203.0.113.0/24"], countries: ["SG"], asns: ["AS64500"])
        let result = PolicyEvaluator().evaluate(identity(country: "US"), against: policy)
        #expect(result.decision == .violated)
        #expect(result.violations == [.countryNotAllowed(actual: "US")])
    }

    @Test("Missing ASN is indeterminate")
    func missingASN() {
        let result = PolicyEvaluator().evaluate(identity(asn: nil), against: policy(asns: ["AS64500"]))
        #expect(result.decision == .indeterminate)
        #expect(result.missingFields == [.asn])
    }

    @Test("Negative country rule rejects a nonmatching country")
    func negativeCountryRule() {
        var settings = GuardSettings.defaults
        settings.rules = [GuardRule(comparison: .isNot, condition: .country, value: "US")]

        let result = PolicyEvaluator().evaluate(identity(country: "SG"), against: NetworkPolicy(settings: settings))

        #expect(result.decision == .violated)
    }

    @Test("Disabled rule is excluded from evaluation")
    func disabledRule() {
        var settings = GuardSettings.defaults
        settings.rules = [GuardRule(condition: .ip, value: "198.51.100.1", isEnabled: false)]

        let result = PolicyEvaluator().evaluate(identity(), against: NetworkPolicy(settings: settings))

        #expect(result.decision == .indeterminate)
    }

    @Test("Direct-exit rule evaluates only the direct identity")
    func directPerspectiveRule() {
        var settings = GuardSettings.defaults
        settings.rules = [GuardRule(
            comparison: .isNot,
            condition: .ip,
            value: "58.240.1.1",
            perspective: .direct
        )]

        let result = PolicyEvaluator().evaluate(
            proxy: identity(ip: "103.54.154.42"),
            direct: identity(ip: "58.240.1.1"),
            against: NetworkPolicy(settings: settings)
        )

        #expect(result.decision == .allowed)
    }

    @Test("Any-exit rule triggers when either identity matches")
    func anyPerspectiveRule() {
        var settings = GuardSettings.defaults
        settings.rules = [GuardRule(
            comparison: .isEqual,
            condition: .ip,
            value: "58.240.1.1",
            perspective: .any
        )]

        let result = PolicyEvaluator().evaluate(
            proxy: identity(ip: "103.54.154.42"),
            direct: identity(ip: "58.240.1.1"),
            against: NetworkPolicy(settings: settings)
        )

        #expect(result.decision == .violated)
        #expect(result.triggeredRuleIDs == Set(settings.rules.map(\.id)))
    }

    @Test("IPv6 CIDR boundaries are supported")
    func ipv6CIDR() {
        let network = try? IPNetwork("2001:db8::/32")
        #expect(network?.contains("2001:db8:ffff::1") == true)
        #expect(network?.contains("2001:db9::1") == false)
    }

    @Test("Invalid policy cannot become a violation")
    func invalidPolicy() {
        let result = PolicyEvaluator().evaluate(identity(), against: policy(cidrs: ["invalid/24"]))
        #expect(result.decision == .indeterminate)
        #expect(result.violations.count == 1)
    }

    private func identity(
        ip: String = "203.0.113.10",
        country: String? = "SG",
        asn: String? = "AS64500"
    ) -> ExitIdentity {
        ExitIdentity(ip: ip, countryCode: country, countryName: nil, asn: asn, organization: nil, provider: "mock", checkedAt: .distantPast)
    }

    private func policy(
        ips: [String] = [], cidrs: [String] = [], countries: [String] = [], asns: [String] = []
    ) -> NetworkPolicy {
        var settings = GuardSettings.defaults
        settings.allowedIPs = ips
        settings.allowedCIDRs = cidrs
        settings.allowedCountryCodes = countries
        settings.allowedASNs = asns
        return NetworkPolicy(settings: settings)
    }
}
