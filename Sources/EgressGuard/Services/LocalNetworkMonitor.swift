import Foundation
import SystemConfiguration

protocol LocalNetworkMonitoring: Sendable {
    func snapshot() async throws -> LocalNetworkSnapshot
}

protocol LocalNetworkCommandRunning: Sendable {
    func output(executable: String, arguments: [String]) async throws -> String
}

struct SystemLocalNetworkMonitor: LocalNetworkMonitoring {
    private let runner: any LocalNetworkCommandRunning
    private let metadataProvider: any LocalNetworkInterfaceMetadataProviding
    private let now: @Sendable () -> Date

    init(
        runner: any LocalNetworkCommandRunning = ProcessNetworkCommandRunner(),
        metadataProvider: any LocalNetworkInterfaceMetadataProviding = SystemConfigurationInterfaceMetadataProvider(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.runner = runner
        self.metadataProvider = metadataProvider
        self.now = now
    }

    func snapshot() async throws -> LocalNetworkSnapshot {
        async let interfaceOutput = runner.output(executable: "/sbin/ifconfig", arguments: ["-a"])
        async let routeOutput = runner.output(executable: "/usr/sbin/netstat", arguments: ["-rn", "-f", "inet"])
        let (interfaces, routes) = try await (interfaceOutput, routeOutput)
        let metadata = metadataProvider.metadataByBSDName()
        let parsedInterfaces = LocalNetworkOutputParser.interfaces(from: interfaces).map { interface in
            let details = metadata[interface.name]
            return LocalNetworkInterface(
                name: interface.name,
                isActive: interface.isActive,
                hardwareAddress: interface.hardwareAddress,
                addresses: interface.addresses,
                displayName: details?.displayName,
                interfaceType: details?.interfaceType
            )
        }
        return LocalNetworkSnapshot(
            interfaces: parsedInterfaces,
            routes: LocalNetworkOutputParser.routes(from: routes),
            checkedAt: now()
        )
    }
}

struct LocalNetworkInterfaceMetadata: Equatable, Sendable {
    let displayName: String?
    let interfaceType: String?
}

protocol LocalNetworkInterfaceMetadataProviding: Sendable {
    func metadataByBSDName() -> [String: LocalNetworkInterfaceMetadata]
}

struct SystemConfigurationInterfaceMetadataProvider: LocalNetworkInterfaceMetadataProviding {
    func metadataByBSDName() -> [String: LocalNetworkInterfaceMetadata] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        return interfaces.reduce(into: [:]) { result, interface in
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String? else { return }
            result[name] = LocalNetworkInterfaceMetadata(
                displayName: SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?,
                interfaceType: SCNetworkInterfaceGetInterfaceType(interface) as String?
            )
        }
    }
}

struct ProcessNetworkCommandRunner: LocalNetworkCommandRunning {
    func output(executable: String, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            try process.run()
            process.waitUntilExit()
            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8) ?? "命令执行失败"
                throw LocalNetworkMonitorError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return String(data: outputData, encoding: .utf8) ?? ""
        }.value
    }
}

enum LocalNetworkMonitorError: LocalizedError, Sendable {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message): message.isEmpty ? "无法读取本地网络状态" : message
        }
    }
}
