import Foundation

struct PolicyEvaluator: Sendable {
    func evaluate(_ identity: ExitIdentity, against policy: NetworkPolicy) -> PolicyEvaluation {
        guard policy.hasConstraints else {
            return PolicyEvaluation(
                decision: .indeterminate,
                violations: [.invalidPolicy(reason: "至少需要配置一条允许规则")],
                missingFields: []
            )
        }

        if policy.usesRuleStack {
            return evaluateRuleStack(proxy: identity, direct: nil, rules: policy.rules)
        }

        var violations: [Violation] = []
        var missingFields: [IdentityField] = []

        let invalidIPs = policy.allowedIPs.filter { !IPNetwork.isValidAddress($0) }
        let parsedCIDRs: [IPNetwork]
        do {
            parsedCIDRs = try policy.allowedCIDRs.map(IPNetwork.init)
        } catch {
            return PolicyEvaluation(
                decision: .indeterminate,
                violations: [.invalidPolicy(reason: "CIDR 格式错误")],
                missingFields: []
            )
        }
        guard invalidIPs.isEmpty else {
            return PolicyEvaluation(
                decision: .indeterminate,
                violations: [.invalidPolicy(reason: "IP 格式错误：\(invalidIPs.sorted().joined(separator: ", "))")],
                missingFields: []
            )
        }

        if !policy.allowedIPs.isEmpty || !policy.allowedCIDRs.isEmpty {
            let exactMatch = policy.allowedIPs.contains(identity.ip)
            let cidrMatch = parsedCIDRs.contains { $0.contains(identity.ip) }
            if !exactMatch && !cidrMatch {
                violations.append(.ipNotAllowed(actual: identity.ip))
            }
        }

        if !policy.allowedCountryCodes.isEmpty {
            if let countryCode = identity.countryCode?.uppercased() {
                if !policy.allowedCountryCodes.contains(countryCode) {
                    violations.append(.countryNotAllowed(actual: countryCode))
                }
            } else {
                missingFields.append(.country)
            }
        }

        if !policy.allowedASNs.isEmpty {
            if let asn = ExitIdentityValidator.normalizeASN(identity.asn) {
                if !policy.allowedASNs.contains(asn) {
                    violations.append(.asnNotAllowed(actual: asn))
                }
            } else {
                missingFields.append(.asn)
            }
        }

        let decision: PolicyEvaluation.Decision
        if !missingFields.isEmpty {
            decision = .indeterminate
        } else if violations.isEmpty {
            decision = .allowed
        } else {
            decision = .violated
        }
        return PolicyEvaluation(decision: decision, violations: violations, missingFields: missingFields)
    }
    func evaluate(
        proxy: ExitIdentity,
        direct: ExitIdentity?,
        against policy: NetworkPolicy
    ) -> PolicyEvaluation {
        guard policy.usesRuleStack else { return evaluate(proxy, against: policy) }
        return evaluateRuleStack(proxy: proxy, direct: direct, rules: policy.rules)
    }

    private func evaluateRuleStack(
        proxy: ExitIdentity,
        direct: ExitIdentity?,
        rules: [GuardRule]
    ) -> PolicyEvaluation {

        guard !rules.isEmpty else {
            return PolicyEvaluation(
                decision: .indeterminate,
                violations: [.invalidPolicy(reason: "至少需要启用一条完整规则")],
                missingFields: []
            )
        }

        var violations: [Violation] = []
        var missingFields: [IdentityField] = []
        var triggeredRuleIDs = Set<UUID>()

        for rule in rules {
            let identities: [ExitIdentity]
            switch rule.perspective {
            case .proxy: identities = [proxy]
            case .direct:
                guard let direct else {
                    missingFields.append(.directExit)
                    continue
                }
                identities = [direct]
            case .any: identities = [proxy] + [direct].compactMap { $0 }
            }

            let triggers: [Bool] = tryRuleMatches(rule, identities: identities, missingFields: &missingFields)
            guard !triggers.isEmpty else { continue }
            let isTriggered = triggers.contains { match in
                rule.comparison == .isEqual ? match : !match
            }
            if isTriggered {
                triggeredRuleIDs.insert(rule.id)
                let appName = rule.application?.displayName ?? "所选应用"
                violations.append(.ruleTriggered(
                    description: "规则已触发：\(rule.comparison.title) \(rule.condition.title) \(rule.value)，\(rule.action.title) \(appName)"
                ))
            }
        }

        if !missingFields.isEmpty {
            return PolicyEvaluation(decision: .indeterminate, violations: violations, missingFields: Array(Set(missingFields)), triggeredRuleIDs: triggeredRuleIDs)
        }
        return PolicyEvaluation(
            decision: violations.isEmpty ? .allowed : .violated,
            violations: violations,
            missingFields: [],
            triggeredRuleIDs: triggeredRuleIDs
        )
    }

    private func tryRuleMatches(
        _ rule: GuardRule,
        identities: [ExitIdentity],
        missingFields: inout [IdentityField]
    ) -> [Bool] {
        switch rule.condition {
        case .ip:
            guard IPNetwork.isValidAddress(rule.value) else { return [] }
            return identities.map { $0.ip == rule.value }
        case .cidr:
            guard let network = try? IPNetwork(rule.value) else { return [] }
            return identities.map { network.contains($0.ip) }
        case .country:
            let countries = identities.compactMap { $0.countryCode?.uppercased() }
            if countries.count != identities.count { missingFields.append(.country) }
            return countries.map { $0 == rule.value.uppercased() }
        }
    }

    private func invalidRule(_ reason: String) -> PolicyEvaluation {
        PolicyEvaluation(decision: .indeterminate, violations: [.invalidPolicy(reason: reason)], missingFields: [])
    }

}
