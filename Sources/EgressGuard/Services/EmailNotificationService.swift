import Foundation
import Security

struct EmailMessage: Equatable, Sendable {
    let subject: String
    let body: String
}

protocol EmailSending: Sendable {
    func send(_ message: EmailMessage, configuration: EmailConfiguration, password: String) async throws
}

enum EmailSendingError: LocalizedError, Equatable {
    case incompleteConfiguration
    case emptyPassword
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .incompleteConfiguration: "邮件配置不完整，请检查 SMTP 服务器和邮箱地址"
        case .emptyPassword: "请输入 SMTP 密码或授权码"
        case let .transport(detail): "邮件发送失败：\(detail)"
        }
    }
}

struct CurlEmailService: EmailSending {
    func send(_ message: EmailMessage, configuration: EmailConfiguration, password: String) async throws {
        guard configuration.isComplete else { throw EmailSendingError.incompleteConfiguration }
        guard !password.isEmpty else { throw EmailSendingError.emptyPassword }

        let payload = Self.payload(message, configuration: configuration)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("egressguard-mail-\(UUID().uuidString).eml")
        try Data(payload.utf8).write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        var arguments = [
            "--silent", "--show-error", "--fail-with-body",
            "--url", Self.serverURL(configuration),
            "--mail-from", configuration.senderAddress,
            "--mail-rcpt", configuration.recipientAddress,
            "--upload-file", temporaryURL.path,
            "--config", "-"
        ]
        if configuration.security == .startTLS { arguments.append("--ssl-reqd") }
        process.arguments = arguments

        let input = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardError = error
        try process.run()
        let credentials = Self.curlCredentialConfiguration(
            username: configuration.username,
            password: password
        )
        try input.fileHandleForWriting.write(contentsOf: Data(credentials.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = error.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw EmailSendingError.transport(detail?.isEmpty == false ? detail! : "SMTP 服务未返回成功状态")
        }
    }

    private static func serverURL(_ configuration: EmailConfiguration) -> String {
        let scheme = configuration.security == .implicitTLS ? "smtps" : "smtp"
        return "\(scheme)://\(configuration.smtpHost):\(configuration.smtpPort)"
    }

    private static func payload(_ message: EmailMessage, configuration: EmailConfiguration) -> String {
        let subject = "=?UTF-8?B?\(Data(message.subject.utf8).base64EncodedString())?="
        return [
            "From: EgressGuard <\(configuration.senderAddress)>",
            "To: \(configuration.recipientAddress)",
            "Subject: \(subject)",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=UTF-8",
            "Content-Transfer-Encoding: base64",
            "",
            Data(message.body.utf8).base64EncodedString(options: .lineLength76Characters),
            ""
        ].joined(separator: "\r\n")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    static func curlCredentialConfiguration(username: String, password: String) -> String {
        // curl does not expose a standalone `password` config option. SMTP credentials
        // must be supplied through its `user` option as username:password.
        "user = \"\(escape(username)):\(escape(password))\"\n"
    }
}

struct EmailPasswordStore: Sendable {
    private let service = "com.egressguard.smtp"
    private let account = "smtp-password"

    func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func save(_ password: String) {
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if password.isEmpty {
            SecItemDelete(key as CFDictionary)
            return
        }
        let attributes = [kSecValueData as String: Data(password.utf8)]
        if SecItemUpdate(key as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var item = key
            item[kSecValueData as String] = Data(password.utf8)
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
