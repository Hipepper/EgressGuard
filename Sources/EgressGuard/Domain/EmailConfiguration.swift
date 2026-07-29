import Foundation

struct EmailConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var smtpHost: String
    var smtpPort: Int
    var security: Security
    var username: String
    var senderAddress: String
    var recipientAddress: String

    static let defaults = EmailConfiguration(
        isEnabled: false,
        smtpHost: "",
        smtpPort: 465,
        security: .implicitTLS,
        username: "",
        senderAddress: "",
        recipientAddress: ""
    )

    enum Security: String, Codable, CaseIterable, Identifiable, Sendable {
        case implicitTLS
        case startTLS
        case none

        var id: Self { self }
        var title: String {
            switch self {
            case .implicitTLS: "SSL/TLS"
            case .startTLS: "STARTTLS"
            case .none: "无加密"
            }
        }
    }

    var isComplete: Bool {
        !smtpHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (1...65_535).contains(smtpPort) &&
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            senderAddress.looksLikeEmailAddress && recipientAddress.looksLikeEmailAddress
    }

    var displayAddress: String {
        recipientAddress.isEmpty ? "未配置收件邮箱" : recipientAddress
    }
}

private extension String {
    var looksLikeEmailAddress: Bool {
        let parts = split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
    }
}
