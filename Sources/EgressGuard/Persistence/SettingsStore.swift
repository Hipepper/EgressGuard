import Foundation

struct SettingsStore {
    private let defaults: UserDefaults
    private let settingsKey = "guardSettings"
    private let applicationsKey = "protectedApplications"
    private let runtimeLogsKey = "runtimeLogs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> GuardSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(GuardSettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    func saveSettings(_ settings: GuardSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    func loadApplications() -> [ProtectedApplication] {
        guard let data = defaults.data(forKey: applicationsKey),
              let applications = try? JSONDecoder().decode([ProtectedApplication].self, from: data) else {
            return []
        }
        return applications
    }

    func saveApplications(_ applications: [ProtectedApplication]) {
        guard let data = try? JSONEncoder().encode(applications) else { return }
        defaults.set(data, forKey: applicationsKey)
    }

    func loadRuntimeLogs() -> [RuntimeLogEntry] {
        guard let data = defaults.data(forKey: runtimeLogsKey),
              let logs = try? JSONDecoder().decode([RuntimeLogEntry].self, from: data) else {
            return []
        }
        return logs
    }

    func saveRuntimeLogs(_ logs: [RuntimeLogEntry]) {
        guard let data = try? JSONEncoder().encode(Array(logs.suffix(1_000))) else { return }
        defaults.set(data, forKey: runtimeLogsKey)
    }
}
