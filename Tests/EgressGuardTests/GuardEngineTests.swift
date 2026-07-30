import Foundation
import Testing
@testable import EgressGuard

@Suite("Guard engine")
struct GuardEngineTests {
    @Test("Violation requires consecutive confirmations and fires once")
    func violationThreshold() async {
        let engine = makeEngine(violationThreshold: 3)
        let violation = evaluation(.violated)

        #expect(await engine.process(violation).state == .suspectedViolation(count: 1))
        #expect(await engine.process(violation).state == .suspectedViolation(count: 2))
        let confirmed = await engine.process(violation)
        #expect(confirmed.state == .confirmedViolation)
        #expect(confirmed.action != nil)
        #expect(await engine.process(violation).action == nil)
    }

    @Test("Every check requires consecutive violation confirmations")
    func everyCheckUsesThreshold() async {
        let engine = GuardEngine(configuration: GuardEngineConfiguration(
            violationThreshold: 3,
            recoveryThreshold: 2,
            startupGracePeriod: 60
        ), now: { Date(timeIntervalSince1970: 100) })

        let update = await engine.process(evaluation(.violated))

        #expect(update.state == .starting)
        #expect(update.action == nil)
    }

    @Test("Provider unavailable does not increment violation count")
    func unavailableDoesNotIncrement() async {
        let engine = makeEngine(violationThreshold: 3)
        _ = await engine.process(evaluation(.violated))
        #expect(await engine.providerUnavailable().state == .providerUnavailable)
        #expect(await engine.process(evaluation(.violated)).state == .suspectedViolation(count: 2))
    }

    @Test("Recovery requires consecutive allowed results")
    func recoveryThreshold() async {
        let engine = makeEngine(violationThreshold: 1, recoveryThreshold: 2)
        _ = await engine.process(evaluation(.violated))
        _ = await engine.markMitigated()
        #expect(await engine.process(evaluation(.allowed)).state == .recovering(count: 1))
        let recovered = await engine.process(evaluation(.allowed))
        #expect(recovered.state == .healthy)
        #expect(recovered.action == .recovered)
    }

    @Test("Indeterminate identity behaves as provider unavailable")
    func indeterminate() async {
        let engine = makeEngine()
        #expect(await engine.process(evaluation(.indeterminate)).state == .providerUnavailable)
    }

    @Test("Paused engine ignores evaluations until resumed")
    func pause() async {
        let engine = makeEngine(violationThreshold: 1)
        _ = await engine.pause(until: nil)
        #expect(await engine.process(evaluation(.violated)).state == .paused(until: nil))
        _ = await engine.resume()
        #expect(await engine.process(evaluation(.allowed)).state == .healthy)
    }

    private func makeEngine(violationThreshold: Int = 3, recoveryThreshold: Int = 2) -> GuardEngine {
        GuardEngine(configuration: GuardEngineConfiguration(
            violationThreshold: violationThreshold,
            recoveryThreshold: recoveryThreshold,
            startupGracePeriod: 0
        ), now: { Date(timeIntervalSince1970: 100) })
    }

    private func evaluation(_ decision: PolicyEvaluation.Decision) -> PolicyEvaluation {
        PolicyEvaluation(
            decision: decision,
            violations: decision == .violated ? [.countryNotAllowed(actual: "US")] : [],
            missingFields: decision == .indeterminate ? [.asn] : []
        )
    }
}
