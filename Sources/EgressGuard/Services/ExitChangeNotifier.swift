import Foundation
import UserNotifications

struct ExitChange: Equatable, Sendable {
    let perspective: GuardRule.Perspective
    let oldIP: String
    let newIP: String
}

enum ExitChangeDetector {
    static func changes(
        previousProxy: ExitIdentity?,
        previousDirect: ExitIdentity?,
        proxy: ExitIdentity?,
        direct: ExitIdentity?
    ) -> [ExitChange] {
        var changes: [ExitChange] = []
        appendChange(from: previousProxy, to: proxy, perspective: .proxy, into: &changes)
        appendChange(from: previousDirect, to: direct, perspective: .direct, into: &changes)
        return changes
    }

    private static func appendChange(
        from previous: ExitIdentity?,
        to current: ExitIdentity?,
        perspective: GuardRule.Perspective,
        into changes: inout [ExitChange]
    ) {
        guard let oldIP = previous?.ipv4Address,
              let newIP = current?.ipv4Address,
              oldIP != newIP else { return }
        changes.append(ExitChange(perspective: perspective, oldIP: oldIP, newIP: newIP))
    }
}

protocol ExitNotificationSending: Sendable {
    func requestAuthorization() async
    func notify(changes: [ExitChange]) async
    func notify(actionResults: [RuleActionResult]) async
}

struct SystemExitNotificationService: ExitNotificationSending {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func notify(changes: [ExitChange]) async {
        for change in changes {
            let content = UNMutableNotificationContent()
            content.title = "公网出口已变化"
            content.body = "\(change.perspective.title)：\(change.oldIP) → \(change.newIP)"
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "egress-change-\(UUID().uuidString)", content: content, trigger: nil)
            )
        }
    }

    func notify(actionResults: [RuleActionResult]) async {
        guard !actionResults.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "保护规则已执行"
        content.body = actionResults.map {
            "\($0.action.title) \($0.applicationName)：\($0.succeeded ? "成功" : "失败")。\($0.detail)"
        }.joined(separator: "；")
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "rule-action-\(UUID().uuidString)", content: content, trigger: nil)
        )
    }
}
