import Foundation

struct ExitIdentity: Codable, Equatable, Sendable {
    let ip: String
    let countryCode: String?
    let countryName: String?
    let asn: String?
    let organization: String?
    let provider: String
    let checkedAt: Date

    var abbreviatedIP: String {
        guard ip.count > 10 else { return ip }
        return "\(ip.prefix(7))…"
    }

    var countryFlag: String {
        guard let code = countryCode?.uppercased(), code.count == 2 else { return "🌐" }
        let scalars = code.unicodeScalars.compactMap {
            UnicodeScalar(127_397 + $0.value)
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
