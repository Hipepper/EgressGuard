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
}
