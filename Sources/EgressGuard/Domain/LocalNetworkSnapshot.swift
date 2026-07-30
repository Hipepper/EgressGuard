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
}

struct LocalRouteEntry: Identifiable, Equatable, Sendable {
    var id: String { "\(destination)|\(gateway)|\(interfaceName)|\(flags)" }
    let destination: String
    let gateway: String
    let flags: String
    let interfaceName: String
    let isStatic: Bool
}
