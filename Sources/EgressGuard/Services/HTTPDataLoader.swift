import Foundation

protocol HTTPDataLoader: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPDataLoader {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request, delegate: nil)
        guard let response = response as? HTTPURLResponse else {
            throw ExitIPProviderError.invalidResponse
        }
        return (data, response)
    }
}
