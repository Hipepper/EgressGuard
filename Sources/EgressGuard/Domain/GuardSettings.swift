import Foundation

struct GuardSettings: Codable, Equatable, Sendable {
    var isProtectionEnabled: Bool
    var checkInterval: TimeInterval
    var requestTimeout: TimeInterval
    var violationThreshold: Int
    var recoveryThreshold: Int
    var startupGracePeriod: TimeInterval
    var allowedIPs: [String]
    var allowedCIDRs: [String]
    var allowedCountryCodes: [String]
    var allowedASNs: [String]

    static let defaults = GuardSettings(
        isProtectionEnabled: false,
        checkInterval: 30,
        requestTimeout: 5,
        violationThreshold: 3,
        recoveryThreshold: 2,
        startupGracePeriod: 60,
        allowedIPs: [],
        allowedCIDRs: [],
        allowedCountryCodes: [],
        allowedASNs: []
    )

    var hasPolicyConstraints: Bool {
        NetworkPolicy(settings: self).hasConstraints
    }
}
