import Foundation

struct IPWhoIsProvider: ExitIPProvider {
    let id = "ipwho.is"
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
        var request = URLRequest(url: URL(string: "https://ipwho.is/")!)
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
        guard payload.success else {
            throw ExitIPProviderError.serviceRejected(payload.message ?? "未知错误")
        }
        guard let ip = payload.ip else { throw ExitIPProviderError.malformedPayload }

        return ExitIdentity(
            ip: try ExitIdentityValidator.validateIP(ip),
            countryCode: try ExitIdentityValidator.validateCountryCode(payload.countryCode),
            countryName: payload.country,
            asn: payload.connection?.asn.map { "AS\($0)" },
            organization: payload.connection?.org ?? payload.connection?.isp,
            provider: id,
            checkedAt: now()
        )
    }
}

private extension IPWhoIsProvider {
    struct Payload: Decodable {
        let ip: String?
        let success: Bool
        let message: String?
        let country: String?
        let countryCode: String?
        let connection: Connection?

        enum CodingKeys: String, CodingKey {
            case ip, success, message, country, connection
            case countryCode = "country_code"
        }
    }

    struct Connection: Decodable {
        let asn: Int?
        let org: String?
        let isp: String?
    }
}
