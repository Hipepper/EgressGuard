import Foundation

enum LocalNetworkOutputParser {
    static func routes(from output: String) -> [LocalRouteEntry] {
        let parsed: [LocalRouteEntry] = output.split(whereSeparator: \Character.isNewline).compactMap { line in
            let columns = line.split(whereSeparator: \Character.isWhitespace).map(String.init)
            guard columns.count >= 4,
                  columns[0] != "Destination",
                  columns[0] != "Routing",
                  !columns[0].hasSuffix(":") else { return nil }

            let flags = columns[2]
            return LocalRouteEntry(
                destination: normalizedIPv4Destination(columns[0]),
                gateway: columns[1],
                flags: flags,
                interfaceName: columns[3],
                isStatic: flags.contains("S") && !columns[1].hasPrefix("link#")
            )
        }
        var seen = Set<String>()
        return parsed.filter {
            seen.insert("\($0.destination)|\($0.gateway)|\($0.interfaceName)").inserted
        }
    }

    static func interfaces(from output: String) -> [LocalNetworkInterface] {
        var interfaces: [LocalNetworkInterface] = []
        var current: InterfaceBuilder?

        func appendCurrent() {
            guard let current else { return }
            interfaces.append(current.interface)
        }

        for rawLine in output.split(whereSeparator: \Character.isNewline) {
            let line = String(rawLine)
            if line.first?.isWhitespace == false,
               let separator = line.firstIndex(of: ":") {
                appendCurrent()
                let name = String(line[..<separator])
                let flags = flagNames(in: line)
                current = InterfaceBuilder(
                    name: name,
                    isActive: flags.contains("UP") && flags.contains("RUNNING")
                )
                continue
            }

            guard current != nil else { continue }
            let columns = line.split(whereSeparator: \Character.isWhitespace).map(String.init)
            guard let key = columns.first else { continue }
            switch key {
            case "ether" where columns.count > 1:
                current?.hardwareAddress = columns[1]
            case "inet" where columns.count > 1:
                let prefix = columns.firstIndex(of: "netmask")
                    .flatMap { columns.indices.contains($0 + 1) ? ipv4Prefix(columns[$0 + 1]) : nil }
                current?.addresses.append(columns[1] + prefix.map { "/\($0)" }.orEmpty)
            case "inet6" where columns.count > 1:
                let prefix = columns.firstIndex(of: "prefixlen")
                    .flatMap { columns.indices.contains($0 + 1) ? Int(columns[$0 + 1]) : nil }
                current?.addresses.append(columns[1] + prefix.map { "/\($0)" }.orEmpty)
            case "status:" where columns.count > 1:
                current?.isActive = columns[1] == "active"
            default:
                break
            }
        }
        appendCurrent()
        return interfaces
    }

    private static func normalizedIPv4Destination(_ value: String) -> String {
        guard value != "default" else { return value }
        let components = value.split(separator: "/", maxSplits: 1).map(String.init)
        guard components.count == 2, Int(components[1]) != nil else { return value }
        var octets = components[0].split(separator: ".").map(String.init)
        guard !octets.isEmpty, octets.count <= 4, octets.allSatisfy({ UInt8($0) != nil }) else { return value }
        octets.append(contentsOf: repeatElement("0", count: 4 - octets.count))
        return "\(octets.joined(separator: "."))/\(components[1])"
    }

    private static func flagNames(in line: String) -> Set<String> {
        guard let start = line.firstIndex(of: "<"), let end = line[start...].firstIndex(of: ">") else { return [] }
        return Set(line[line.index(after: start)..<end].split(separator: ",").map(String.init))
    }

    private static func ipv4Prefix(_ mask: String) -> Int? {
        guard mask.hasPrefix("0x"), let value = UInt32(mask.dropFirst(2), radix: 16) else { return nil }
        return value.nonzeroBitCount
    }

    private struct InterfaceBuilder {
        let name: String
        var isActive: Bool
        var hardwareAddress: String?
        var addresses: [String] = []

        var interface: LocalNetworkInterface {
            LocalNetworkInterface(
                name: name,
                isActive: isActive,
                hardwareAddress: hardwareAddress,
                addresses: addresses
            )
        }
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
