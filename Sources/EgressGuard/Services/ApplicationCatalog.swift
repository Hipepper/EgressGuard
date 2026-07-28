import AppKit
import Foundation

struct InstalledApplication: Identifiable, Hashable, Sendable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let displayName: String
    let url: URL
}

struct ApplicationCatalog: Sendable {
    func runningApplications() async -> [InstalledApplication] {
        await MainActor.run {
            NSWorkspace.shared.runningApplications.compactMap { application in
                guard application.activationPolicy == .regular,
                      let bundleIdentifier = application.bundleIdentifier,
                      let url = application.bundleURL else {
                    return nil
                }
                return InstalledApplication(
                    bundleIdentifier: bundleIdentifier,
                    displayName: application.localizedName ?? url.deletingPathExtension().lastPathComponent,
                    url: url
                )
            }
            .uniquedByBundleIdentifier()
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }
}

private extension Sequence where Element == InstalledApplication {
    func uniquedByBundleIdentifier() -> [InstalledApplication] {
        var identifiers = Set<String>()
        return filter { identifiers.insert($0.bundleIdentifier).inserted }
    }
}
