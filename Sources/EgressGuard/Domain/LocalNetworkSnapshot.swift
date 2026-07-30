import Foundation

struct LocalNetworkSnapshot: Equatable, Sendable {
    var interfaces: [LocalNetworkInterface]
    var routes: [LocalRouteEntry]
    var checkedAt: Date

    static let empty = LocalNetworkSnapshot(interfaces: [], routes: [], checkedAt: .distantPast)
}

struct LocalNetworkInterface: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let isActive: Bool
    let hardwareAddress: String?
    let addresses: [String]
    let displayName: String?
    let kind: LocalNetworkInterfaceKind

    init(
        name: String,
        isActive: Bool,
        hardwareAddress: String?,
        addresses: [String],
        displayName: String? = nil,
        interfaceType: String? = nil
    ) {
        self.name = name
        self.isActive = isActive
        self.hardwareAddress = hardwareAddress
        self.addresses = addresses
        self.displayName = displayName
        kind = LocalNetworkInterfaceKind.classify(
            name: name,
            displayName: displayName,
            interfaceType: interfaceType
        )
    }
}

enum LocalNetworkInterfaceKind: String, Equatable, Sendable {
    case wifi
    case ethernet
    case tunnel
    case bridge
    case loopback
    case systemVirtual
    case other

    static func classify(name: String, displayName: String?, interfaceType: String?) -> Self {
        let metadata = [displayName, interfaceType].compactMap { $0 }.joined(separator: " ").lowercased()
        if metadata.contains("wi-fi") || metadata.contains("wifi") || metadata.contains("airport") || metadata.contains("ieee80211") { return .wifi }
        if metadata.contains("ethernet") || metadata.contains("usb 10/") || metadata.contains("thunderbolt ethernet") { return .ethernet }
        if name == "lo0" { return .loopback }
        if name.hasPrefix("utun") || name.hasPrefix("gif") || name.hasPrefix("stf") || name.hasPrefix("ipsec") { return .tunnel }
        if name.hasPrefix("bridge") { return .bridge }
        if ["awdl", "llw", "anpi", "p2p", "ap"].contains(where: name.hasPrefix) { return .systemVirtual }
        return .other
    }

    var title: String {
        switch self {
        case .wifi: "无线网络"
        case .ethernet: "有线网络"
        case .tunnel: "隧道 / VPN"
        case .bridge: "网桥"
        case .loopback: "本机回环"
        case .systemVirtual: "系统虚拟接口"
        case .other: "其他接口"
        }
    }

    var sourceDescription: String {
        switch self {
        case .wifi, .ethernet: "系统硬件网络端口"
        case .tunnel: "VPN、代理或系统网络扩展（无法确定具体应用）"
        case .bridge: "系统或虚拟化软件创建的网桥"
        case .loopback: "macOS 内核"
        case .systemVirtual: "macOS 系统服务"
        case .other: "来源未知"
        }
    }

    var symbolName: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "cable.connector"
        case .tunnel: "lock.shield"
        case .bridge: "point.3.connected.trianglepath.dotted"
        case .loopback: "arrow.triangle.2.circlepath"
        case .systemVirtual: "cpu"
        case .other: "network"
        }
    }
}

struct LocalRouteEntry: Identifiable, Equatable, Sendable {
    var id: String { "\(destination)|\(gateway)|\(interfaceName)|\(flags)" }
    let destination: String
    let gateway: String
    let flags: String
    let interfaceName: String
    let isStatic: Bool

    var kind: LocalRouteKind {
        if destination == "default" { return .defaultRoute }
        if gateway.contains(":") { return .neighborCache }
        if interfaceName.hasPrefix("utun") || interfaceName.hasPrefix("gif") || interfaceName.hasPrefix("stf") { return .tunnelPolicy }
        if isStatic { return .staticGateway }
        if gateway.hasPrefix("link#") { return .directNetwork }
        return .other
    }

    var isPolicyRoute: Bool {
        [.defaultRoute, .staticGateway, .tunnelPolicy].contains(kind)
    }
}

enum LocalRouteKind: String, Equatable, Sendable, CaseIterable {
    case defaultRoute
    case staticGateway
    case tunnelPolicy
    case directNetwork
    case neighborCache
    case other

    var title: String {
        switch self {
        case .defaultRoute: "默认路由"
        case .staticGateway: "静态网关"
        case .tunnelPolicy: "TUN 策略"
        case .directNetwork: "直连网段"
        case .neighborCache: "邻居缓存"
        case .other: "其他路由"
        }
    }
}
