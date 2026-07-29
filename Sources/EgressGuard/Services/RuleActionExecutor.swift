import AppKit
import Foundation

protocol ApplicationActionPerforming: Sendable {
    func open(_ application: GuardRule.Application) async -> Bool
    func close(_ application: GuardRule.Application) async -> Bool
}

struct SystemApplicationActionPerformer: ApplicationActionPerforming {
    func open(_ application: GuardRule.Application) async -> Bool {
        guard let url = application.url else { return false }
        return await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }

    func close(_ application: GuardRule.Application) async -> Bool {
        await MainActor.run {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: application.bundleIdentifier)
            guard !running.isEmpty else { return true }
            return running.map { $0.terminate() }.allSatisfy { $0 }
        }
    }
}

struct RuleActionResult: Equatable, Sendable {
    let ruleID: UUID
    let applicationName: String
    let action: GuardRule.Action
    let succeeded: Bool
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
            let succeeded = switch rule.action {
            case .open: await performer.open(application)
            case .close: await performer.close(application)
            }
            results.append(RuleActionResult(
                ruleID: rule.id,
                applicationName: application.displayName,
                action: rule.action,
                succeeded: succeeded
            ))
        }
        return results
    }
}
