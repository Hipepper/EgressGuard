import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    var status: GuardDisplayStatus = .starting
    var identity: ExitIdentity?
    var settings: GuardSettings {
        didSet { settingsStore.saveSettings(settings) }
    }
    var protectedApplications: [ProtectedApplication] {
        didSet { settingsStore.saveApplications(protectedApplications) }
    }
    var selectedSettingsSection: SettingsSection? = .overview
    var lastErrorMessage: String?
    var policyMessage: String?

    private let providerCoordinator: ProviderCoordinator
    private let settingsStore: SettingsStore
    private var monitoringTask: Task<Void, Never>?
    private let guardEngine = GuardEngine(configuration: GuardEngineConfiguration(
        violationThreshold: GuardSettings.defaults.violationThreshold,
        recoveryThreshold: GuardSettings.defaults.recoveryThreshold,
        startupGracePeriod: GuardSettings.defaults.startupGracePeriod
    ))

    init(providerCoordinator: ProviderCoordinator? = nil, settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        settings = settingsStore.loadSettings()
        protectedApplications = settingsStore.loadApplications()
        self.providerCoordinator = providerCoordinator ?? ProviderCoordinator(providers: [
            IPWhoIsProvider(),
            IPAPICoProvider(),
            IPIPNetProvider()
        ])
    }

    var menuBarTitle: String {
        guard let identity else { return "EgressGuard" }
        return "\(identity.countryFlag) \(identity.abbreviatedIP)"
    }

    func checkNow() {
        guard status != .checking else { return }
        status = .checking
        lastErrorMessage = nil
        Task {
            do {
                let fetchedIdentity = try await providerCoordinator.fetchIdentity()
                identity = fetchedIdentity
                if settings.isProtectionEnabled && settings.hasPolicyConstraints {
                    await guardEngine.updateConfiguration(engineConfiguration)
                    let evaluation = PolicyEvaluator().evaluate(
                        fetchedIdentity,
                        against: NetworkPolicy(settings: settings)
                    )
                    policyMessage = evaluation.violations.first?.description ?? evaluation.missingFields.first.map {
                        "检测源未提供\($0 == .asn ? " ASN" : "国家/地区")，暂不执行处置"
                    }
                    let update = await guardEngine.process(evaluation)
                    apply(update.state)
                } else {
                    policyMessage = settings.isProtectionEnabled ? "请先配置至少一条允许规则" : nil
                    status = .healthy
                }
            } catch is CancellationError {
                return
            } catch {
                lastErrorMessage = error.localizedDescription
                status = .unavailable
            }
        }
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        checkNow()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(max(15, self.settings.checkInterval)))
                guard !Task.isCancelled else { return }
                if self.status != .paused {
                    self.checkNow()
                }
            }
        }
    }

    func pauseProtection() {
        Task {
            let update = await guardEngine.pause(until: nil)
            apply(update.state)
        }
    }

    func resumeProtection() {
        Task {
            let update = await guardEngine.resume()
            apply(update.state)
            checkNow()
        }
    }

    func addApplications(_ applications: [InstalledApplication]) {
        let existing = Set(protectedApplications.map(\.bundleIdentifier))
        protectedApplications.append(contentsOf: applications.compactMap { application in
            guard !existing.contains(application.bundleIdentifier),
                  application.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return nil
            }
            return ProtectedApplication(
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationURL: application.url
            )
        })
    }

    func removeApplications(at offsets: IndexSet) {
        protectedApplications.remove(atOffsets: offsets)
    }

    private var engineConfiguration: GuardEngineConfiguration {
        GuardEngineConfiguration(
            violationThreshold: settings.violationThreshold,
            recoveryThreshold: settings.recoveryThreshold,
            startupGracePeriod: settings.startupGracePeriod
        )
    }

    private func apply(_ state: GuardState) {
        switch state {
        case .starting: status = .starting
        case .healthy: status = .healthy
        case let .suspectedViolation(count): status = .suspectedViolation(count: count)
        case .confirmedViolation, .mitigated: status = .violation
        case let .recovering(count): status = .recovering(count: count)
        case .providerUnavailable: status = .unavailable
        case .paused: status = .paused
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case rules
    case applications
    case notifications
    case history

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "常规"
        case .rules: "保护规则"
        case .applications: "受保护应用"
        case .notifications: "通知"
        case .history: "历史记录"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "gearshape"
        case .rules: "checklist"
        case .applications: "app.badge.checkmark"
        case .notifications: "bell"
        case .history: "clock.arrow.circlepath"
        }
    }
}
