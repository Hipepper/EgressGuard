import Foundation

struct PolicyEvaluation: Equatable, Sendable {
    enum Decision: Equatable, Sendable {
        case allowed
        case violated
        case indeterminate
    }

    let decision: Decision
    let violations: [Violation]
    let missingFields: [IdentityField]
}

enum IdentityField: String, Equatable, Sendable {
    case country
    case asn
}

enum Violation: Equatable, Sendable {
    case ipNotAllowed(actual: String)
    case countryNotAllowed(actual: String)
    case asnNotAllowed(actual: String)
    case invalidPolicy(reason: String)
    case ruleTriggered(description: String)

    var description: String {
        switch self {
        case let .ipNotAllowed(actual): "IP \(actual) 不在允许范围内"
        case let .countryNotAllowed(actual): "国家/地区 \(actual) 不在允许列表内"
        case let .asnNotAllowed(actual): "ASN \(actual) 不在允许列表内"
        case let .invalidPolicy(reason): "规则无效：\(reason)"
        case let .ruleTriggered(description): description
        }
    }
}
