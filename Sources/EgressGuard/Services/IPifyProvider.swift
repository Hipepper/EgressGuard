import Foundation

struct IPifyProvider: ExitIPProvider {
    let id = "api.ipify.org"
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
        var request = URLRequest(url: URL(string: "https://api.ipify.org?format=json")!)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("EgressGuard/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await loader.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ExitIPProviderError.httpStatus(response.statusCode)
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let address = try? ExitIdentityValidator.validateIP(payload.ip),
              !address.contains(":") else {
            throw ExitIPProviderError.malformedPayload
        }
        return ExitIdentity(
            ip: address,
            countryCode: nil,
            countryName: nil,
            asn: nil,
            organization: nil,
            provider: id,
            checkedAt: now()
        )
    }

    private struct Payload: Decodable { let ip: String }
}
