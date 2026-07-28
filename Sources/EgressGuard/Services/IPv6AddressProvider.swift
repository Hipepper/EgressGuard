import Foundation
import Network

protocol IPv6AddressProviding: Sendable {
    func fetchAddress() async throws -> String
}

struct IPv6AddressProvider: IPv6AddressProviding {
    private let loader: any HTTPDataLoader
    private let timeout: TimeInterval

    init(loader: any HTTPDataLoader = URLSession.shared, timeout: TimeInterval = 4) {
        self.loader = loader
        self.timeout = timeout
    }

    func fetchAddress() async throws -> String {
        var request = URLRequest(url: URL(string: "https://6.ipw.cn")!)
        request.timeoutInterval = timeout
        request.setValue("EgressGuard/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await loader.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ExitIPProviderError.httpStatus(response.statusCode)
        }
        guard let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              IPv6Address(value) != nil else {
            throw ExitIPProviderError.malformedPayload
        }
        return value
    }
}
