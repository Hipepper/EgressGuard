import Foundation
import Testing
@testable import EgressGuard

@Suite("Network change monitoring")
struct NetworkChangeMonitorTests {
    @Test("Direct requests explicitly disable every system proxy mode")
    func directProxyConfigurationDisablesAllModes() {
        let values = DirectHTTPDataLoader.disabledProxyConfiguration

        #expect(values["HTTPEnable"] as? Int == 0)
        #expect(values["HTTPSEnable"] as? Int == 0)
        #expect(values["SOCKSEnable"] as? Int == 0)
        #expect(values["ProxyAutoConfigEnable"] as? Int == 0)
        #expect(values["ProxyAutoDiscoveryEnable"] as? Int == 0)
    }

    @Test("Bursting system events are coalesced while later changes trigger")
    func networkChangeGateCoalescesBursts() async {
        let gate = NetworkChangeGate(minimumInterval: 0.5)

        #expect(await gate.shouldTrigger(at: Date(timeIntervalSince1970: 10)))
        #expect(await gate.shouldTrigger(at: Date(timeIntervalSince1970: 10.1)) == false)
        #expect(await gate.shouldTrigger(at: Date(timeIntervalSince1970: 10.6)))
    }
}
