import Foundation

struct ProtectedApplication: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let displayName: String
    let applicationURL: URL?
    var forceTerminateAfterTimeout: Bool

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        applicationURL: URL?,
        forceTerminateAfterTimeout: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationURL = applicationURL
        self.forceTerminateAfterTimeout = forceTerminateAfterTimeout
    }
}
