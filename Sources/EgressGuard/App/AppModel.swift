import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    var status: GuardDisplayStatus = .starting
    var identity: ExitIdentity?
    var directIdentity: ExitIdentity?
    var settings: GuardSettings {
        didSet {
            settingsStore.saveSettings(settings)
            if settings.checkInterval != oldValue.checkInterval {
                restartPeriodicMonitoring()
            }
        }
    }
    var protectedApplications: [ProtectedApplication] {
        didSet { settingsStore.saveApplications(protectedApplications) }
    }
    var selectedSettingsSection: SettingsSection? = .overview
    var lastErrorMessage: String?
    var policyMessage: String?
    var ruleTestStatuses: [UUID: RuleTestStatus] = [:]

    private let providerCoordinator: ProviderCoordinator
    private let directProviderCoordinator: ProviderCoordinator
    private let settingsStore: SettingsStore
    private let actionExecutor: RuleActionExecutor
    private let notificationService: any ExitNotificationSending
    private let networkChangeMonitor: any NetworkChangeMonitoring
    private var monitoringTask: Task<Void, Never>?
    private var networkRefreshTask: Task<Void, Never>?
    private let guardEngine = GuardEngine(configuration: GuardEngineConfiguration(
        violationThreshold: GuardSettings.defaults.violationThreshold,
        recoveryThreshold: GuardSettings.defaults.recoveryThreshold,
        startupGracePeriod: GuardSettings.defaults.startupGracePeriod
    ))

    init(
        providerCoordinator: ProviderCoordinator? = nil,
        directProviderCoordinator: ProviderCoordinator? = nil,
        settingsStore: SettingsStore = SettingsStore(),
        actionExecutor: RuleActionExecutor = RuleActionExecutor(),
        notificationService: any ExitNotificationSending = SystemExitNotificationService(),
        networkChangeMonitor: any NetworkChangeMonitoring = SystemNetworkChangeMonitor()
    ) {
        self.settingsStore = settingsStore
        self.actionExecutor = actionExecutor
        self.notificationService = notificationService
        self.networkChangeMonitor = networkChangeMonitor
        settings = settingsStore.loadSettings()
        protectedApplications = settingsStore.loadApplications()
        self.providerCoordinator = providerCoordinator ?? ProviderCoordinator(providers: [
            IPWhoIsProvider(),
            IPAPICoProvider(),
            IPIPNetProvider()
        ])
        self.directProviderCoordinator = directProviderCoordinator ?? ProviderCoordinator(providers: [
            IPifyProvider(loader: DirectHTTPDataLoader())
        ])
    }

    var hasSplitEgress: Bool {
        guard let proxyIP = identity?.ipv4Address, let directIP = directIdentity?.ipv4Address else { return false }
        return proxyIP != directIP
    }

    var menuBarText: String? {
        var parts: [String] = []
        if let identity {
            switch settings.menuBarCountryDisplayMode {
            case .hidden: break
            case .flag: parts.append(identity.countryFlag)
            case .code:
                if let code = identity.countryCode?.uppercased() { parts.append(code) }
            }
        }
        if let ipv4 = identity?.ipv4Address {
            switch settings.menuBarIPDisplayMode {
            case .iconOnly: break
            case .fullIPv4: parts.append(ipv4)
            case .abbreviatedIPv4: parts.append(ipv4.abbreviatedIPv4)
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    func checkNow() {
        checkNow(isManual: true)
    }

    private func checkNow(isManual: Bool) {
        guard status != .checking else { return }
        status = .checking
        lastErrorMessage = nil
        Task {
            async let proxyFetch = try? providerCoordinator.fetchIdentity()
            async let directFetch = try? directProviderCoordinator.fetchIdentity()
            let (proxyResult, directResult) = await (proxyFetch, directFetch)
            guard let policyIdentity = proxyResult ?? directResult else {
                lastErrorMessage = ExitIPProviderError.allProvidersFailed.localizedDescription
                status = .unavailable
                return
            }

            let changes = ExitChangeDetector.changes(
                previousProxy: identity,
                previousDirect: directIdentity,
                proxy: proxyResult,
                direct: directResult
            )
            identity = proxyResult
            directIdentity = directResult
            await notificationService.notify(changes: changes)

            if settings.isProtectionActive {
                await guardEngine.updateConfiguration(engineConfiguration)
                let evaluation = PolicyEvaluator().evaluate(
                    proxy: policyIdentity,
                    direct: directResult,
                    against: NetworkPolicy(settings: settings)
                )
                policyMessage = evaluation.violations.first?.description ?? evaluation.missingFields.first.map {
                    "检测源未提供\($0 == .asn ? " ASN" : ($0 == .directExit ? "直连出口" : "国家/地区"))，暂不执行处置"
                }
                let update = isManual
                    ? await guardEngine.processImmediately(evaluation)
                    : await guardEngine.process(evaluation)
                apply(update.state)
                if case .confirmViolation = update.action {
                    let results = await actionExecutor.execute(
                        rules: settings.rules,
                        triggeredRuleIDs: evaluation.triggeredRuleIDs
                    )
                    await notificationService.notify(actionResults: results)
                    let mitigated = await guardEngine.markMitigated()
                    apply(mitigated.state)
                }
            } else {
                policyMessage = settings.hasPolicyConstraints ? "保护规则已停用" : "请先配置至少一条完整规则"
                status = .healthy
            }
        }
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        Task { await notificationService.requestAuthorization() }
        checkNow(isManual: false)
        networkChangeMonitor.start { [weak self] in
            Task { @MainActor in self?.scheduleNetworkRefresh() }
        }
        startPeriodicMonitoring()
    }

    private func startPeriodicMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(max(1, self.settings.checkInterval)))
                guard !Task.isCancelled else { return }
                if self.status != .paused {
                    self.checkNow(isManual: false)
                }
            }
        }
    }

    private func restartPeriodicMonitoring() {
        guard monitoringTask != nil else { return }
        monitoringTask?.cancel()
        startPeriodicMonitoring()
    }

    private func scheduleNetworkRefresh() {
        networkRefreshTask?.cancel()
        networkRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            while self.status == .checking && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !Task.isCancelled, self.status != .paused else { return }
            self.checkNow(isManual: true)
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

    func testRule(_ id: UUID) {
        guard let rule = settings.rules.first(where: { $0.id == id }), rule.application != nil else {
            ruleTestStatuses[id] = .unavailable
            return
        }
        ruleTestStatuses[id] = .running
        Task {
            await notificationService.requestAuthorization()
            guard let result = await actionExecutor.test(rule: rule) else {
                ruleTestStatuses[id] = .unavailable
                return
            }
            ruleTestStatuses[id] = result.succeeded ? .succeeded(result.detail) : .failed(result.detail)
            await notificationService.notify(actionResults: [result])
        }
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

enum RuleTestStatus: Equatable, Sendable {
    case running
    case succeeded(String)
    case failed(String)
    case unavailable

    var detail: String? {
        switch self {
        case let .succeeded(detail), let .failed(detail): detail
        case .running: "正在直接测试规则配置的应用动作…"
        case .unavailable: "规则尚未选择目标应用"
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case rules
    case notifications
    case history
    case preferences

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "概览"
        case .rules: "保护规则"
        case .notifications: "通知"
        case .history: "历史记录"
        case .preferences: "设置"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .rules: "checklist"
        case .notifications: "bell"
        case .history: "clock.arrow.circlepath"
        case .preferences: "gearshape"
        }
    }
}
