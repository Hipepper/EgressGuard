import Foundation
import Network

struct IPNetwork: Equatable, Sendable {
    private let networkBytes: Data
    private let prefixLength: Int

    init(_ notation: String) throws {
        let parts = notation.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let prefix = Int(parts[1]),
              let bytes = Self.bytes(for: String(parts[0])) else {
            throw ExitIPProviderError.invalidIPAddress(notation)
        }
        let maximumPrefix = bytes.count * 8
        guard (0...maximumPrefix).contains(prefix) else {
            throw ExitIPProviderError.invalidIPAddress(notation)
        }
        networkBytes = bytes
        prefixLength = prefix
    }

    func contains(_ address: String) -> Bool {
        guard let addressBytes = Self.bytes(for: address), addressBytes.count == networkBytes.count else {
            return false
        }

        let completeBytes = prefixLength / 8
        let remainingBits = prefixLength % 8
        for index in 0..<completeBytes where networkBytes[index] != addressBytes[index] {
            return false
        }
        guard remainingBits > 0 else { return true }
        let mask = UInt8.max << (8 - remainingBits)
        return networkBytes[completeBytes] & mask == addressBytes[completeBytes] & mask
    }

    static func isValidAddress(_ address: String) -> Bool {
        bytes(for: address) != nil
    }

    private static func bytes(for address: String) -> Data? {
        if let value = IPv4Address(address) { return value.rawValue }
        if let value = IPv6Address(address) { return value.rawValue }
        return nil
    }
}
