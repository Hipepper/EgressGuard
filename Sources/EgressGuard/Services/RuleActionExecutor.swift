import AppKit
import Foundation

protocol ApplicationActionPerforming: Sendable {
    func open(_ application: GuardRule.Application) async -> ActionExecutionOutcome
    func close(_ application: GuardRule.Application) async -> ActionExecutionOutcome
}

struct ActionExecutionOutcome: Equatable, Sendable {
    let succeeded: Bool
    let detail: String

    static func success(_ detail: String) -> Self { Self(succeeded: true, detail: detail) }
    static func failure(_ detail: String) -> Self { Self(succeeded: false, detail: detail) }
}

struct SystemApplicationActionPerformer: ApplicationActionPerforming {
    func open(_ application: GuardRule.Application) async -> ActionExecutionOutcome {
        guard let url = application.url else {
            return .failure("缺少应用路径，请重新选择目标应用")
        }
        let opened = await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        return opened
            ? .success("已打开 \(application.displayName)")
            : .failure("macOS 未能打开 \(application.displayName)，请确认应用仍位于原路径")
    }

    func close(_ application: GuardRule.Application) async -> ActionExecutionOutcome {
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            return .failure("当前构建启用了 App Sandbox；Apple 禁止沙箱应用终止其他应用。请安装关闭 App Sandbox 的直接分发版本")
        }

        let (applications, requestsAccepted) = await MainActor.run {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: application.bundleIdentifier)
            let accepted = running.map { $0.terminate() }
            return (running, accepted)
        }
        guard !applications.isEmpty else {
            return .success("\(application.displayName) 当前未运行，无需关闭")
        }
        guard requestsAccepted.allSatisfy({ $0 }) else {
            return .failure("macOS 拒绝向 \(application.displayName) 发送退出请求。请确认运行的是关闭 App Sandbox 的 EgressGuard 构建")
        }
        try? await Task.sleep(for: .milliseconds(800))
        let remaining = await MainActor.run { applications.filter { !$0.isTerminated } }
        for application in remaining {
            await MainActor.run { _ = application.forceTerminate() }
        }
        try? await Task.sleep(for: .milliseconds(300))
        let terminated = await MainActor.run { applications.allSatisfy(\.isTerminated) }
        return terminated
            ? .success("已确认 \(application.displayName) 进程退出")
            : .failure("已请求关闭 \(application.displayName)，但进程仍在运行；目标应用可能拒绝退出或由其他服务自动重启")
    }
}

struct RuleActionResult: Equatable, Sendable {
    let ruleID: UUID
    let applicationName: String
    let action: GuardRule.Action
    let succeeded: Bool
    let detail: String
}

actor RuleActionExecutor {
    private let performer: any ApplicationActionPerforming

    init(performer: any ApplicationActionPerforming = SystemApplicationActionPerformer()) {
        self.performer = performer
    }

    func execute(rules: [GuardRule], triggeredRuleIDs: Set<UUID>) async -> [RuleActionResult] {
        var results: [RuleActionResult] = []
        for rule in rules where triggeredRuleIDs.contains(rule.id) && rule.isEnabled {
            guard let application = rule.application else { continue }
            let outcome = switch rule.action {
            case .open: await performer.open(application)
            case .close: await performer.close(application)
            }
            results.append(RuleActionResult(
                ruleID: rule.id,
                applicationName: application.displayName,
                action: rule.action,
                succeeded: outcome.succeeded,
                detail: outcome.detail
            ))
        }
        return results
    }

    func test(rule: GuardRule) async -> RuleActionResult? {
        guard let application = rule.application else { return nil }
        let outcome = switch rule.action {
        case .open: await performer.open(application)
        case .close: await performer.close(application)
        }
        return RuleActionResult(
            ruleID: rule.id,
            applicationName: application.displayName,
            action: rule.action,
            succeeded: outcome.succeeded,
            detail: outcome.detail
        )
    }
}
