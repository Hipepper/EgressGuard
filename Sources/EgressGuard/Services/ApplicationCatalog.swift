import AppKit
import Foundation

struct InstalledApplication: Identifiable, Hashable, Sendable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let displayName: String
    let url: URL
    let isRunning: Bool

    init(bundleIdentifier: String, displayName: String, url: URL, isRunning: Bool = false) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.url = url
        self.isRunning = isRunning
    }
}

struct ApplicationCatalog: Sendable {
    func applications() async -> [InstalledApplication] {
        let installed = installedApplications()
        let running = await runningApplications()
        return Self.merging(installed: installed, running: running)
    }

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
                    url: url,
                    isRunning: true
                )
            }
            .uniquedByBundleIdentifier()
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    static func merging(
        installed: [InstalledApplication],
        running: [InstalledApplication]
    ) -> [InstalledApplication] {
        var applications = Dictionary(uniqueKeysWithValues: installed.map { ($0.bundleIdentifier, $0) })
        for application in running {
            applications[application.bundleIdentifier] = InstalledApplication(
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                url: application.url,
                isRunning: true
            )
        }
        return applications.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func installedApplications() -> [InstalledApplication] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ] + fileManager.urls(for: .applicationDirectory, in: .userDomainMask)

        return roots.flatMap { root -> [InstalledApplication] in
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return [] }

            var applications: [InstalledApplication] = []
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                guard let bundle = Bundle(url: url), let bundleIdentifier = bundle.bundleIdentifier else { continue }
                let displayName = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                applications.append(InstalledApplication(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    url: url
                ))
            }
            return applications
        }
        .uniquedByBundleIdentifier()
    }
}

private extension Sequence where Element == InstalledApplication {
    func uniquedByBundleIdentifier() -> [InstalledApplication] {
        var identifiers = Set<String>()
        return filter { identifiers.insert($0.bundleIdentifier).inserted }
    }
}
