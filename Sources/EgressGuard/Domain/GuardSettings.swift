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
    var rules: [GuardRule]
    var menuBarIPDisplayMode: MenuBarIPDisplayMode
    var showsCountryFlagInMenuBar: Bool
    var checkIntervalUnit: RefreshIntervalUnit
    var menuBarCountryDisplayMode: MenuBarCountryDisplayMode
    var interfaceTheme: InterfaceTheme

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
        rules: [
            GuardRule(condition: .ip, value: "203.0.113.10", isEnabled: false),
            GuardRule(condition: .cidr, value: "203.0.113.0/24", isEnabled: false),
            GuardRule(condition: .country, value: "SG", isEnabled: false)
        ],
        menuBarIPDisplayMode: .iconOnly,
        showsCountryFlagInMenuBar: false,
        checkIntervalUnit: .seconds,
        menuBarCountryDisplayMode: .hidden,
        interfaceTheme: .system
    )

    var hasPolicyConstraints: Bool {
        NetworkPolicy(settings: self).hasConstraints
    }

    var isProtectionActive: Bool {
        if !rules.isEmpty {
            return hasPolicyConstraints
        }
        return isProtectionEnabled && hasPolicyConstraints
    }

    mutating func setProtectionActive(_ isActive: Bool) {
        if rules.isEmpty {
            isProtectionEnabled = isActive
        } else {
            for index in rules.indices {
                rules[index].isEnabled = isActive
            }
            isProtectionEnabled = isActive
        }
    }

    mutating func addRule(_ rule: GuardRule = GuardRule()) {
        rules.insert(rule, at: 0)
    }

    var checkIntervalValue: Double {
        checkInterval / checkIntervalUnit.secondsMultiplier
    }

    mutating func setCheckInterval(value: Double, unit: RefreshIntervalUnit) {
        checkIntervalUnit = unit
        checkInterval = max(1, value * unit.secondsMultiplier)
    }

    var showsIPInMenuBar: Bool {
        get { menuBarIPDisplayMode != .iconOnly }
        set { menuBarIPDisplayMode = newValue ? .fullIPv4 : .iconOnly }
    }
}

enum RefreshIntervalUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case seconds
    case minutes

    var id: Self { self }
    var title: String { self == .seconds ? "秒" : "分钟" }
    var secondsMultiplier: Double { self == .seconds ? 1 : 60 }
}

enum InterfaceTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }
    var title: String {
        switch self {
        case .system: "自动"
        case .light: "白天"
        case .dark: "黑夜"
        }
    }
    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

enum MenuBarCountryDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case hidden
    case flag
    case code

    var id: Self { self }
    var title: String {
        switch self {
        case .hidden: "不显示"
        case .flag: "国旗"
        case .code: "国家/地区缩写"
        }
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
        case allowedIPs, allowedCIDRs, allowedCountryCodes, allowedASNs, rules
        case menuBarIPDisplayMode, showsCountryFlagInMenuBar
        case checkIntervalUnit, menuBarCountryDisplayMode, interfaceTheme
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
            rules: [],
            menuBarIPDisplayMode: try container.decodeIfPresent(MenuBarIPDisplayMode.self, forKey: .menuBarIPDisplayMode) ?? .iconOnly,
            showsCountryFlagInMenuBar: try container.decodeIfPresent(Bool.self, forKey: .showsCountryFlagInMenuBar) ?? false,
            checkIntervalUnit: try container.decodeIfPresent(RefreshIntervalUnit.self, forKey: .checkIntervalUnit) ?? .seconds,
            menuBarCountryDisplayMode: .hidden,
            interfaceTheme: try container.decodeIfPresent(InterfaceTheme.self, forKey: .interfaceTheme) ?? .system
        )
        menuBarCountryDisplayMode = try container.decodeIfPresent(MenuBarCountryDisplayMode.self, forKey: .menuBarCountryDisplayMode)
            ?? (showsCountryFlagInMenuBar ? .flag : .hidden)
        if let decodedRules = try container.decodeIfPresent([GuardRule].self, forKey: .rules) {
            rules = decodedRules
        } else {
            rules = Self.migrateLegacyRules(
                ips: allowedIPs,
                cidrs: allowedCIDRs,
                countries: allowedCountryCodes
            )
        }
    }

    private static func migrateLegacyRules(ips: [String], cidrs: [String], countries: [String]) -> [GuardRule] {
        let ipRules = ips.map { GuardRule(comparison: .isNot, condition: .ip, value: $0) }
        let cidrRules = cidrs.map { GuardRule(comparison: .isNot, condition: .cidr, value: $0) }
        let countryRules = countries.map { GuardRule(comparison: .isNot, condition: .country, value: $0) }
        return ipRules + cidrRules + countryRules
    }
}

enum ContinuousSelection {
    static func index(position: CGFloat, totalExtent: CGFloat, itemCount: Int) -> Int? {
        guard totalExtent > 0, itemCount > 0 else { return nil }
        let itemExtent = totalExtent / CGFloat(itemCount)
        return min(max(Int(position / itemExtent), 0), itemCount - 1)
    }
}

enum SettingsLayoutMetrics {
    static let selectionAnimationDuration = 0.16
    static let themeCommitDelay = 0.10
    static let overviewHeaderHeight: CGFloat = 170
    static let contentCornerRadius: CGFloat = 22
}
