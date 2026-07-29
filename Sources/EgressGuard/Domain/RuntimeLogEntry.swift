import Foundation

struct RuntimeLogEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sessionID: UUID
    let timestamp: Date
    let category: Category
    let level: Level
    let message: String
    let detail: String?

    init(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        timestamp: Date = Date(),
        category: Category,
        level: Level = .info,
        message: String,
        detail: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
        self.detail = detail
    }

    enum Category: String, Codable, CaseIterable, Sendable {
        case lifecycle
        case detection
        case rule
        case email
        case error

        var title: String {
            switch self {
            case .lifecycle: "生命周期"
            case .detection: "出口检测"
            case .rule: "规则运行"
            case .email: "邮件通知"
            case .error: "错误"
            }
        }

        var symbolName: String {
            switch self {
            case .lifecycle: "power"
            case .detection: "network"
            case .rule: "checklist.checked"
            case .email: "envelope"
            case .error: "exclamationmark.triangle"
            }
        }
    }

    enum Level: String, Codable, Sendable {
        case info
        case success
        case warning
        case error
    }
}
