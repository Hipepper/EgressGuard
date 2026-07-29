import Testing
@testable import EgressGuard

@Suite("Email configuration")
struct EmailConfigurationTests {
    @Test("Complete SMTP configuration is accepted")
    func completeConfiguration() {
        let configuration = EmailConfiguration(
            isEnabled: true,
            smtpHost: "smtp.example.com",
            smtpPort: 465,
            security: .implicitTLS,
            username: "sender@example.com",
            senderAddress: "sender@example.com",
            recipientAddress: "alerts@example.com"
        )
        #expect(configuration.isComplete)
    }

    @Test("Invalid recipient and port are rejected")
    func invalidConfiguration() {
        var configuration = EmailConfiguration.defaults
        configuration.smtpHost = "smtp.example.com"
        configuration.username = "sender@example.com"
        configuration.senderAddress = "sender@example.com"
        configuration.recipientAddress = "invalid"
        configuration.smtpPort = 0
        #expect(!configuration.isComplete)
    }

    @Test("curl receives SMTP username and authorization code through its user option")
    func curlCredentials() {
        let configuration = CurlEmailService.curlCredentialConfiguration(
            username: "sender@163.com",
            password: "authorization-code"
        )
        #expect(configuration == "user = \"sender@163.com:authorization-code\"\n")
        #expect(!configuration.contains("\npassword ="))
    }
}
