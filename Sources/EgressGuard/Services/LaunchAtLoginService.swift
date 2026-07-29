import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case failed(String)

    var isEnabled: Bool { self == .enabled }

    var title: String {
        switch self {
        case .disabled: "开机自启动未开启"
        case .enabled: "开机自启动已开启"
        case .requiresApproval: "等待系统批准"
        case .failed: "设置失败"
        }
    }

    var detail: String {
        switch self {
        case .disabled: "登录 Mac 后不会自动运行"
        case .enabled: "登录 Mac 后自动启动 EgressGuard"
        case .requiresApproval: "请在系统设置的登录项中允许 EgressGuard"
        case let .failed(message): message
        }
    }
}

@MainActor
protocol LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ isEnabled: Bool) throws
    func openSystemSettings()
}

@MainActor
struct SystemLaunchAtLoginService: LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        // A stale or not-yet-created registration can report notFound even though
        // the main application itself is valid and can still call register().
        case .notFound: .disabled
        @unknown default: .disabled
        }
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
