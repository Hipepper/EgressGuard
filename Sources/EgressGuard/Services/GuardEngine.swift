import Foundation

actor GuardEngine {
    private(set) var state: GuardState = .starting
    private var configuration: GuardEngineConfiguration
    private var graceUntil: Date
    private var stateBeforeUnavailable: GuardState = .starting
    private let now: @Sendable () -> Date

    init(
        configuration: GuardEngineConfiguration,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.now = now
        graceUntil = now().addingTimeInterval(configuration.startupGracePeriod)
    }

    func updateConfiguration(_ newConfiguration: GuardEngineConfiguration) {
        guard newConfiguration != configuration else { return }
        configuration = newConfiguration
        state = .starting
        graceUntil = now().addingTimeInterval(newConfiguration.startupGracePeriod)
    }

    func process(_ evaluation: PolicyEvaluation) -> GuardEngineUpdate {
        if case let .paused(until) = state {
            if let until, until <= now() {
                state = .starting
                graceUntil = now()
            } else {
                return GuardEngineUpdate(state: state, action: nil)
            }
        }

        if now() < graceUntil {
            state = .starting
            return GuardEngineUpdate(state: state, action: nil)
        }

        if state == .providerUnavailable {
            state = stateBeforeUnavailable
        }

        switch evaluation.decision {
        case .indeterminate:
            return providerUnavailable()
        case .allowed:
            return processAllowed()
        case .violated:
            return processViolation(evaluation.violations)
        }
    }

    func providerUnavailable() -> GuardEngineUpdate {
        if state != .providerUnavailable { stateBeforeUnavailable = state }
        state = .providerUnavailable
        return GuardEngineUpdate(state: state, action: nil)
    }

    func markMitigated() -> GuardEngineUpdate {
        guard state == .confirmedViolation else {
            return GuardEngineUpdate(state: state, action: nil)
        }
        state = .mitigated
        return GuardEngineUpdate(state: state, action: nil)
    }

    func pause(until: Date?) -> GuardEngineUpdate {
        state = .paused(until: until)
        return GuardEngineUpdate(state: state, action: nil)
    }

    func resume() -> GuardEngineUpdate {
        state = .starting
        graceUntil = now()
        return GuardEngineUpdate(state: state, action: nil)
    }

    private func processAllowed() -> GuardEngineUpdate {
        switch state {
        case .confirmedViolation, .mitigated, .recovering:
            let previousCount = if case let .recovering(count) = state { count } else { 0 }
            let count = previousCount + 1
            if count >= max(1, configuration.recoveryThreshold) {
                state = .healthy
                return GuardEngineUpdate(state: state, action: .recovered)
            }
            state = .recovering(count: count)
        default:
            state = .healthy
        }
        return GuardEngineUpdate(state: state, action: nil)
    }

    private func processViolation(_ violations: [Violation]) -> GuardEngineUpdate {
        switch state {
        case .confirmedViolation, .mitigated:
            return GuardEngineUpdate(state: state, action: nil)
        default:
            let previousCount = if case let .suspectedViolation(count) = state { count } else { 0 }
            let count = previousCount + 1
            if count >= max(1, configuration.violationThreshold) {
                state = .confirmedViolation
                return GuardEngineUpdate(state: state, action: .confirmViolation(violations))
            }
            state = .suspectedViolation(count: count)
            return GuardEngineUpdate(state: state, action: nil)
        }
    }
}
