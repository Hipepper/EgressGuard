import Foundation

struct NetworkPolicy: Equatable, Sendable {
    var allowedIPs: Set<String>
    var allowedCIDRs: Set<String>
    var allowedCountryCodes: Set<String>
    var allowedASNs: Set<String>

    var hasConstraints: Bool {
        !allowedIPs.isEmpty || !allowedCIDRs.isEmpty ||
            !allowedCountryCodes.isEmpty || !allowedASNs.isEmpty
    }

    init(settings: GuardSettings) {
        allowedIPs = Set(settings.allowedIPs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        allowedCIDRs = Set(settings.allowedCIDRs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        allowedCountryCodes = Set(settings.allowedCountryCodes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty })
        allowedASNs = Set(settings.allowedASNs.map { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return normalized.hasPrefix("AS") ? normalized : "AS\(normalized)"
        }.filter { $0 != "AS" })
    }
}
