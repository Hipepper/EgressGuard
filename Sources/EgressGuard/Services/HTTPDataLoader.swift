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

struct FreshHTTPDataLoader: HTTPDataLoader {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        return try await session.data(for: request)
    }
}

struct DirectHTTPDataLoader: HTTPDataLoader {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        return try await session.data(for: request)
    }
}
