import Foundation
import Testing
@testable import EgressGuard

@Suite("Exit IP providers")
struct ProviderTests {
    private let fixedDate = Date(timeIntervalSince1970: 1_000)

    @Test("ipwho.is response is parsed and normalized")
    func ipWhoIsParsing() async throws {
        let loader = StubLoader(statusCode: 200, body: #"""
        {
            "ip":"203.0.113.10","success":true,"country":"Singapore",
            "country_code":"sg","connection":{"asn":64500,"org":"Example Net","isp":"Example ISP"}
        }
        """#)
        let provider = IPWhoIsProvider(loader: loader, now: { fixedDate })

        let identity = try await provider.fetchIdentity()

        #expect(identity.ip == "203.0.113.10")
        #expect(identity.countryCode == "SG")
        #expect(identity.asn == "AS64500")
        #expect(identity.organization == "Example Net")
        #expect(identity.provider == "ipwho.is")
        #expect(identity.checkedAt == fixedDate)
    }

    @Test("ipapi.co response is parsed")
    func ipAPICoParsing() async throws {
        let loader = StubLoader(statusCode: 200, body: #"""
        {
            "ip":"2001:db8::1","country_code":"US","country_name":"United States",
            "asn":"AS15169","org":"Google LLC"
        }
        """#)
        let provider = IPAPICoProvider(loader: loader, now: { fixedDate })

        let identity = try await provider.fetchIdentity()

        #expect(identity.ip == "2001:db8::1")
        #expect(identity.countryCode == "US")
        #expect(identity.asn == "AS15169")
    }

    @Test("Application-level errors are not accepted as identities")
    func applicationError() async {
        let loader = StubLoader(statusCode: 200, body: #"{"success":false,"message":"Reserved range"}"#)
        let provider = IPWhoIsProvider(loader: loader)

        await #expect(throws: ExitIPProviderError.serviceRejected("Reserved range")) {
            try await provider.fetchIdentity()
        }
    }

    @Test("IPIP.net fallback parses Chinese location without inventing ASN")
    func ipIPNetParsing() async throws {
        let loader = StubLoader(statusCode: 200, body: #"""
        {"ret":"ok","data":{"ip":"203.0.113.10","location":["中国","江苏","南京","","中国电信"]}}
        """#)
        let provider = IPIPNetProvider(loader: loader, now: { fixedDate })

        let identity = try await provider.fetchIdentity()

        #expect(identity.ip == "203.0.113.10")
        #expect(identity.countryCode == "CN")
        #expect(identity.countryName == "中国")
        #expect(identity.organization == "中国电信")
        #expect(identity.asn == nil)
        #expect(identity.provider == "myip.ipip.net")
    }

    @Test("Localized country names resolve to ISO country codes")
    func localizedCountryCode() {
        #expect(CountryCodeResolver.code(forLocalizedName: "新加坡") == "SG")
        #expect(CountryCodeResolver.code(forLocalizedName: "Singapore") == "SG")
        #expect(CountryCodeResolver.code(forLocalizedName: "中国香港") == "HK")
    }

    @Test("Coordinator falls back to the second provider")
    func fallback() async throws {
        let coordinator = ProviderCoordinator(providers: [
            StubProvider(id: "failed", result: .failure(ExitIPProviderError.httpStatus(500))),
            StubProvider(id: "working", result: .success(sampleIdentity(provider: "working")))
        ])

        let identity = try await coordinator.fetchIdentity()

        #expect(identity.provider == "working")
    }

    @Test("Coordinator reports all providers unavailable")
    func allUnavailable() async {
        let coordinator = ProviderCoordinator(providers: [
            StubProvider(id: "one", result: .failure(ExitIPProviderError.httpStatus(429))),
            StubProvider(id: "two", result: .failure(ExitIPProviderError.malformedPayload))
        ])

        await #expect(throws: ExitIPProviderError.allProvidersFailed) {
            try await coordinator.fetchIdentity()
        }
    }

    @Test("Dedicated IPv6 provider parses a reachable IPv6 address")
    func ipv6AddressParsing() async throws {
        let provider = IPv6AddressProvider(
            loader: StubLoader(statusCode: 200, body: "2001:db8::42\n")
        )

        let address = try await provider.fetchAddress()

        #expect(address == "2001:db8::42")
    }

    @Test("Dedicated IPv6 provider rejects IPv4 responses")
    func ipv6AddressRejectsIPv4() async {
        let provider = IPv6AddressProvider(
            loader: StubLoader(statusCode: 200, body: "203.0.113.10")
        )

        await #expect(throws: ExitIPProviderError.malformedPayload) {
            try await provider.fetchAddress()
        }
    }

    private func sampleIdentity(provider: String) -> ExitIdentity {
        ExitIdentity(
            ip: "203.0.113.10",
            countryCode: "SG",
            countryName: "Singapore",
            asn: "AS64500",
            organization: "Example",
            provider: provider,
            checkedAt: fixedDate
        )
    }
}

private struct StubLoader: HTTPDataLoader {
    let statusCode: Int
    let body: String

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}

private struct StubProvider: ExitIPProvider {
    let id: String
    let result: Result<ExitIdentity, ExitIPProviderError>

    func fetchIdentity() async throws -> ExitIdentity {
        try result.get()
    }
}
