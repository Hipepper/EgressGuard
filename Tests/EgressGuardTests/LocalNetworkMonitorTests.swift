import Testing
@testable import EgressGuard

@Suite("Local network monitor")
struct LocalNetworkMonitorTests {
    @Test("Monitor combines interface and route command output")
    func buildsSnapshot() async throws {
        let monitor = SystemLocalNetworkMonitor(
            runner: StubNetworkCommandRunner(),
            now: { .distantFuture }
        )

        let snapshot = try await monitor.snapshot()

        #expect(snapshot.interfaces.map(\.name) == ["en7"])
        #expect(snapshot.routes.map(\.destination) == ["10.10.0.0/16"])
        #expect(snapshot.checkedAt == .distantFuture)
    }

    @Test("Static IPv4 route is normalized and identified")
    func parsesStaticRoute() {
        let output = """
        Routing tables

        Internet:
        Destination        Gateway            Flags               Netif Expire
        default            10.88.32.1         UGScg                 en0
        10.10/16           10.220.0.1         UGSc                  en7
        10.10/16           10.220.0.1         UGScI                 en7
        10.88.32/21        link#15            UCS                   en0      !
        """

        let routes = LocalNetworkOutputParser.routes(from: output)

        #expect(routes.count == 3)
        #expect(routes[0].destination == "default")
        #expect(routes[1].destination == "10.10.0.0/16")
        #expect(routes[1].gateway == "10.220.0.1")
        #expect(routes[1].interfaceName == "en7")
        #expect(routes[1].isStatic)
        #expect(!routes[2].isStatic)
    }

    @Test("Interface parser collects addresses and active state")
    func parsesInterfaces() {
        let output = """
        en7: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            ether 00:11:22:33:44:55
            inet 10.220.0.20 netmask 0xffffff00 broadcast 10.220.0.255
            inet6 fe80::1%en7 prefixlen 64 secured scopeid 0x17
            status: active
        utun8: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 2000
            inet 198.18.0.1 --> 198.18.0.1 netmask 0xffffffff
        """

        let interfaces = LocalNetworkOutputParser.interfaces(from: output)

        #expect(interfaces.count == 2)
        #expect(interfaces[0].name == "en7")
        #expect(interfaces[0].isActive)
        #expect(interfaces[0].hardwareAddress == "00:11:22:33:44:55")
        #expect(interfaces[0].addresses == ["10.220.0.20/24", "fe80::1%en7/64"])
        #expect(interfaces[1].name == "utun8")
        #expect(interfaces[1].isActive)
        #expect(interfaces[1].addresses == ["198.18.0.1/32"])
    }
}

private struct StubNetworkCommandRunner: LocalNetworkCommandRunning {
    func output(executable: String, arguments: [String]) async throws -> String {
        if executable.hasSuffix("ifconfig") {
            return """
            en7: flags=8863<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500
                inet 10.220.0.20 netmask 0xffffff00
                status: active
            """
        }
        return """
        Destination Gateway Flags Netif Expire
        10.10/16 10.220.0.1 UGSc en7
        """
    }
}
