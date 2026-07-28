import Foundation

struct IPAPICoProvider: ExitIPProvider {
    let id = "ipapi.co"
    private let loader: any HTTPDataLoader
    private let timeout: TimeInterval
    private let now: @Sendable () -> Date

    init(
        loader: any HTTPDataLoader = URLSession.shared,
        timeout: TimeInterval = 5,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loader = loader
        self.timeout = timeout
        self.now = now
    }

    func fetchIdentity() async throws -> ExitIdentity {
        var request = URLRequest(url: URL(string: "https://ipapi.co/json/")!)
        request.timeoutInterval = timeout
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
        if payload.error == true {
            throw ExitIPProviderError.serviceRejected(payload.message ?? payload.reason ?? "未知错误")
        }
        guard let ip = payload.ip else { throw ExitIPProviderError.malformedPayload }

        return ExitIdentity(
            ip: try ExitIdentityValidator.validateIP(ip),
            countryCode: try ExitIdentityValidator.validateCountryCode(payload.countryCode ?? payload.country),
            countryName: payload.countryName,
            asn: ExitIdentityValidator.normalizeASN(payload.asn),
            organization: payload.org,
            provider: id,
            checkedAt: now()
        )
    }
}

private extension IPAPICoProvider {
    struct Payload: Decodable {
        let ip: String?
        let country: String?
        let countryCode: String?
        let countryName: String?
        let asn: String?
        let org: String?
        let error: Bool?
        let reason: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case ip, country, asn, org, error, reason, message
            case countryCode = "country_code"
            case countryName = "country_name"
        }
    }
}
