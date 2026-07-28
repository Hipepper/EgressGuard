import Foundation
import Network

enum ExitIdentityValidator {
    static func validateIP(_ value: String) throws -> String {
        guard IPv4Address(value) != nil || IPv6Address(value) != nil else {
            throw ExitIPProviderError.invalidIPAddress(value)
        }
        return value
    }

    static func validateCountryCode(_ value: String?) throws -> String? {
        guard let value else { return nil }
        let normalized = value.uppercased()
        guard normalized.count == 2,
              normalized.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) else {
            throw ExitIPProviderError.invalidCountryCode(value)
        }
        return normalized
    }

    static func normalizeASN(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.uppercased().hasPrefix("AS") ? String(value.dropFirst(2)) : value
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return "AS\(digits)"
    }
}
