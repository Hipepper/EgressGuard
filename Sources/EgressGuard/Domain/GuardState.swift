import Foundation

enum GuardState: Equatable, Sendable {
    case starting
    case healthy
    case suspectedViolation(count: Int)
    case confirmedViolation
    case mitigated
    case recovering(count: Int)
    case providerUnavailable
    case paused(until: Date?)
}

enum GuardEngineAction: Equatable, Sendable {
    case confirmViolation([Violation])
    case recovered
}

struct GuardEngineUpdate: Equatable, Sendable {
    let state: GuardState
    let action: GuardEngineAction?
}

struct GuardEngineConfiguration: Equatable, Sendable {
    var violationThreshold: Int
    var recoveryThreshold: Int
    var startupGracePeriod: TimeInterval
}
