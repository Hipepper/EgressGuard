import Foundation

struct GuardRule: Codable, Equatable, Identifiable, Sendable {
    enum Perspective: String, Codable, CaseIterable, Identifiable, Sendable {
        case proxy
        case direct
        case any

        var id: Self { self }
        var title: String {
            switch self {
            case .proxy: "代理出口"
            case .direct: "无代理出口"
            case .any: "任一出口"
            }
        }
    }

    enum Comparison: String, Codable, CaseIterable, Identifiable, Sendable {
        case isEqual
        case isNot

        var id: Self { self }
        var title: String { self == .isEqual ? "是" : "不是" }
    }

    enum Condition: String, Codable, CaseIterable, Identifiable, Sendable {
        case ip
        case cidr
        case country

        var id: Self { self }
        var title: String {
            switch self {
            case .ip: "出口 IP"
            case .cidr: "出口 CIDR"
            case .country: "出口国家/地区"
            }
        }
    }

    enum Action: String, Codable, CaseIterable, Identifiable, Sendable {
        case close
        case open

        var id: Self { self }
        var title: String { self == .close ? "关闭" : "打开" }
        var symbolName: String { self == .close ? "xmark.circle.fill" : "play.circle.fill" }
    }

    struct Application: Codable, Equatable, Sendable {
        var bundleIdentifier: String
        var displayName: String
        var url: URL?
    }

    var id: UUID
    var perspective: Perspective
    var comparison: Comparison
    var condition: Condition
    var value: String
    var action: Action
    var application: Application?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        comparison: Comparison = .isNot,
        condition: Condition = .ip,
        value: String = "",
        perspective: Perspective = .any,
        action: Action = .close,
        application: Application? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.perspective = perspective
        self.comparison = comparison
        self.condition = condition
        self.value = value
        self.action = action
        self.application = application
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, perspective, comparison, condition, value, action, application, isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        perspective = try container.decodeIfPresent(Perspective.self, forKey: .perspective) ?? .any
        comparison = try container.decode(Comparison.self, forKey: .comparison)
        condition = try container.decode(Condition.self, forKey: .condition)
        value = try container.decode(String.self, forKey: .value)
        action = try container.decode(Action.self, forKey: .action)
        application = try container.decodeIfPresent(Application.self, forKey: .application)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    var isComplete: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && application != nil
    }
}
