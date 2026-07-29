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
    static var disabledProxyConfiguration: [AnyHashable: Any] {
        [
            "HTTPEnable": 0,
            "HTTPSEnable": 0,
            "SOCKSEnable": 0,
            "ProxyAutoConfigEnable": 0,
            "ProxyAutoDiscoveryEnable": 0
        ]
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = Self.disabledProxyConfiguration
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        return try await session.data(for: request)
    }
}
