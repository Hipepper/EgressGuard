import Darwin
import Foundation
import Network

protocol IPv6AddressProviding: Sendable {
    func fetchAddress() async throws -> String
}

protocol IPv6EndpointResolving: Sendable {
    func hasUsableIPv6Address(for host: String) -> Bool
}

struct DNSIPv6EndpointResolver: IPv6EndpointResolving {
    func hasUsableIPv6Address(for host: String) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_INET6
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, "443", &hints, &result) == 0, let result else {
            return false
        }
        defer { freeaddrinfo(result) }

        var current: UnsafeMutablePointer<addrinfo>? = result
        while let entry = current {
            if entry.pointee.ai_family == AF_INET6,
               let socketAddress = entry.pointee.ai_addr {
                let ipv6 = socketAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                var address = ipv6.sin6_addr
                let bytes = withUnsafeBytes(of: &address) { Array($0) }
                if Self.isUsableNativeIPv6(bytes) { return true }
            }
            current = entry.pointee.ai_next
        }
        return false
    }

    static func isUsableNativeIPv6(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return false }
        let isUnspecified = bytes.allSatisfy { $0 == 0 }
        let isLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
        let isIPv4Mapped = bytes.prefix(10).allSatisfy { $0 == 0 } && bytes[10] == 0xff && bytes[11] == 0xff
        let isLinkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
        let isUniqueLocal = (bytes[0] & 0xfe) == 0xfc
        let isMulticast = bytes[0] == 0xff
        return !isUnspecified && !isLoopback && !isIPv4Mapped && !isLinkLocal && !isUniqueLocal && !isMulticast
    }
}

struct IPv6AddressProvider: IPv6AddressProviding {
    private static let endpoint = URL(string: "https://6.ipw.cn")!

    private let loader: any HTTPDataLoader
    private let resolver: any IPv6EndpointResolving
    private let timeout: TimeInterval

    init(
        loader: any HTTPDataLoader = URLSession.shared,
        resolver: any IPv6EndpointResolving = DNSIPv6EndpointResolver(),
        timeout: TimeInterval = 4
    ) {
        self.loader = loader
        self.resolver = resolver
        self.timeout = timeout
    }

    func fetchAddress() async throws -> String {
        guard resolver.hasUsableIPv6Address(for: Self.endpoint.host!) else {
            throw ExitIPProviderError.ipv6Unavailable
        }

        var request = URLRequest(url: Self.endpoint)
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
