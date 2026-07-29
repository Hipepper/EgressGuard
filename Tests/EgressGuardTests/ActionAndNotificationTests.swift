import Foundation
import Testing
@testable import EgressGuard

@Suite("Rule actions and exit changes")
struct ActionAndNotificationTests {
    @Test("Executor performs the action for each triggered rule")
    func executesTriggeredRule() async {
        let performer = RecordingApplicationPerformer()
        let executor = RuleActionExecutor(performer: performer)
        let rule = GuardRule(
            comparison: .isNot,
            condition: .ip,
            value: "103.54.154.42",
            action: .close,
            application: .init(
                bundleIdentifier: "com.example.Target",
                displayName: "Target",
                url: URL(fileURLWithPath: "/Applications/Target.app")
            )
        )

        let results = await executor.execute(rules: [rule], triggeredRuleIDs: [rule.id])

        #expect(results.count == 1)
        #expect(results.first?.succeeded == true)
        #expect(await performer.actions == ["close:com.example.Target"])
    }

    @Test("Rule test directly performs its configured action even when the rule is disabled")
    func testsConfiguredActionDirectly() async {
        let performer = RecordingApplicationPerformer()
        let executor = RuleActionExecutor(performer: performer)
        let rule = GuardRule(
            comparison: .isEqual,
            condition: .cidr,
            value: "103.54.0.0/16",
            perspective: .proxy,
            action: .close,
            application: .init(
                bundleIdentifier: "com.example.NetNewsWire",
                displayName: "NetNewsWire",
                url: nil
            ),
            isEnabled: false
        )

        let result = await executor.test(rule: rule)

        #expect(result?.succeeded == true)
        #expect(result?.detail == "测试执行成功")
        #expect(await performer.actions == ["close:com.example.NetNewsWire"])
    }

    @Test("IP change detector ignores the initial sample")
    func ignoresInitialSample() {
        let current = identity("58.240.164.101")
        #expect(ExitChangeDetector.changes(previousProxy: nil, previousDirect: nil, proxy: current, direct: current).isEmpty)
    }

    @Test("IP change detector reports a proxy change")
    func reportsProxyChange() {
        let changes = ExitChangeDetector.changes(
            previousProxy: identity("103.54.154.42"),
            previousDirect: identity("58.240.164.101"),
            proxy: identity("58.240.164.101"),
            direct: identity("58.240.164.101")
        )
        #expect(changes == [.init(perspective: .proxy, oldIP: "103.54.154.42", newIP: "58.240.164.101")])
    }

    private func identity(_ ip: String) -> ExitIdentity {
        ExitIdentity(ip: ip, countryCode: nil, countryName: nil, asn: nil, organization: nil, provider: "test", checkedAt: .distantPast)
    }
}

private actor RecordingApplicationPerformer: ApplicationActionPerforming {
    private(set) var actions: [String] = []

    func open(_ application: GuardRule.Application) async -> ActionExecutionOutcome {
        actions.append("open:\(application.bundleIdentifier)")
        return .success("测试执行成功")
    }

    func close(_ application: GuardRule.Application) async -> ActionExecutionOutcome {
        actions.append("close:\(application.bundleIdentifier)")
        return .success("测试执行成功")
    }
}
