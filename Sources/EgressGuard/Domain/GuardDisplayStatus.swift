import SwiftUI

enum GuardDisplayStatus: Equatable, Sendable {
    case starting
    case checking
    case healthy
    case suspectedViolation(count: Int)
    case violation
    case recovering(count: Int)
    case unavailable
    case paused

    var title: String {
        switch self {
        case .starting: "正在启动"
        case .checking: "正在检测"
        case .healthy: "保护正常"
        case let .suspectedViolation(count): "规则待确认（\(count)）"
        case .violation: "规则已触发"
        case let .recovering(count): "正在确认恢复（\(count)）"
        case .unavailable: "暂时无法检测"
        case .paused: "保护已暂停"
        }
    }

    var symbolName: String {
        switch self {
        case .starting, .checking: "arrow.triangle.2.circlepath"
        case .healthy: "checkmark.shield.fill"
        case .suspectedViolation: "exclamationmark.shield"
        case .violation: "exclamationmark.shield.fill"
        case .recovering: "arrow.clockwise.circle"
        case .unavailable: "wifi.exclamationmark"
        case .paused: "pause.circle.fill"
        }
    }

    var menuBarSymbolName: String { symbolName }

    var color: Color {
        switch self {
        case .healthy: .green
        case .suspectedViolation: .orange
        case .violation: .red
        case .recovering: .blue
        case .unavailable: .orange
        case .paused: .secondary
        case .starting, .checking: .blue
        }
    }
}
