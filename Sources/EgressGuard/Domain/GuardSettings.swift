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
    var menuBarIPDisplayMode: MenuBarIPDisplayMode
    var showsCountryFlagInMenuBar: Bool

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
        allowedASNs: [],
        menuBarIPDisplayMode: .iconOnly,
        showsCountryFlagInMenuBar: false
    )

    var hasPolicyConstraints: Bool {
        NetworkPolicy(settings: self).hasConstraints
    }
}

enum MenuBarIPDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case iconOnly
    case fullIPv4
    case abbreviatedIPv4

    var id: Self { self }

    var title: String {
        switch self {
        case .iconOnly: "仅显示状态图标"
        case .fullIPv4: "显示完整 IPv4"
        case .abbreviatedIPv4: "显示 IPv4 前两段"
        }
    }

    var example: String {
        switch self {
        case .iconOnly: "◈"
        case .fullIPv4: "203.0.113.10"
        case .abbreviatedIPv4: "203.0…"
        }
    }
}

extension GuardSettings {
    private enum CodingKeys: String, CodingKey {
        case isProtectionEnabled, checkInterval, requestTimeout
        case violationThreshold, recoveryThreshold, startupGracePeriod
        case allowedIPs, allowedCIDRs, allowedCountryCodes, allowedASNs
        case menuBarIPDisplayMode, showsCountryFlagInMenuBar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isProtectionEnabled: try container.decode(Bool.self, forKey: .isProtectionEnabled),
            checkInterval: try container.decode(TimeInterval.self, forKey: .checkInterval),
            requestTimeout: try container.decode(TimeInterval.self, forKey: .requestTimeout),
            violationThreshold: try container.decode(Int.self, forKey: .violationThreshold),
            recoveryThreshold: try container.decode(Int.self, forKey: .recoveryThreshold),
            startupGracePeriod: try container.decode(TimeInterval.self, forKey: .startupGracePeriod),
            allowedIPs: try container.decode([String].self, forKey: .allowedIPs),
            allowedCIDRs: try container.decode([String].self, forKey: .allowedCIDRs),
            allowedCountryCodes: try container.decode([String].self, forKey: .allowedCountryCodes),
            allowedASNs: try container.decode([String].self, forKey: .allowedASNs),
            menuBarIPDisplayMode: try container.decodeIfPresent(MenuBarIPDisplayMode.self, forKey: .menuBarIPDisplayMode) ?? .iconOnly,
            showsCountryFlagInMenuBar: try container.decodeIfPresent(Bool.self, forKey: .showsCountryFlagInMenuBar) ?? false
        )
    }
}
