import Foundation

/// Mainland-reachable fallback for IP and country detection.
/// This endpoint does not provide ASN data, so ASN must remain unknown.
struct IPIPNetProvider: ExitIPProvider {
    let id = "myip.ipip.net"
    private let loader: any HTTPDataLoader
    private let timeout: TimeInterval
    private let now: @Sendable () -> Date

    init(
        loader: any HTTPDataLoader = FreshHTTPDataLoader(),
        timeout: TimeInterval = 5,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loader = loader
        self.timeout = timeout
        self.now = now
    }

    func fetchIdentity() async throws -> ExitIdentity {
        var request = URLRequest(url: URL(string: "https://myip.ipip.net/json")!)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("EgressGuard/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await loader.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ExitIPProviderError.httpStatus(response.statusCode)
        }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw ExitIPProviderError.malformedPayload
        }
        guard payload.ret == "ok", let result = payload.data else {
            throw ExitIPProviderError.serviceRejected(payload.ret)
        }

        let countryName = result.location.first.flatMap { $0.isEmpty ? nil : $0 }
        return ExitIdentity(
            ip: try ExitIdentityValidator.validateIP(result.ip),
            countryCode: CountryCodeResolver.code(forLocalizedName: countryName),
            countryName: countryName,
            asn: nil,
            organization: result.location.last.flatMap { $0.isEmpty ? nil : $0 },
            provider: id,
            checkedAt: now()
        )
    }
}

private extension IPIPNetProvider {
    struct Payload: Decodable {
        let ret: String
        let data: Result?
    }

    struct Result: Decodable {
        let ip: String
        let location: [String]
    }
}

enum CountryCodeResolver {
    private static let aliases: [String: String] = [
        "中国": "CN",
        "中国大陆": "CN",
        "中国香港": "HK",
        "中国澳门": "MO",
        "中国台湾": "TW"
    ]

    static func code(forLocalizedName name: String?) -> String? {
        guard let name else { return nil }
        if let alias = aliases[name] { return alias }

        for code in Locale.Region.isoRegions.map(\.identifier) {
            if Locale(identifier: "zh_Hans").localizedString(forRegionCode: code) == name ||
                Locale(identifier: "en_US").localizedString(forRegionCode: code) == name {
                return code
            }
        }
        return nil
    }
}
