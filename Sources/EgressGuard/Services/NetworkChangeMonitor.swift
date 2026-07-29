import Foundation
import Network
import SystemConfiguration

protocol NetworkChangeMonitoring: AnyObject, Sendable {
    func start(handler: @escaping @Sendable () -> Void)
    func stop()
}

actor NetworkChangeGate {
    private let minimumInterval: TimeInterval
    private var lastTrigger: Date?

    init(minimumInterval: TimeInterval = 0.5) {
        self.minimumInterval = minimumInterval
    }

    func shouldTrigger(at date: Date = Date()) -> Bool {
        if let lastTrigger, date.timeIntervalSince(lastTrigger) < minimumInterval {
            return false
        }
        lastTrigger = date
        return true
    }
}

final class SystemNetworkChangeMonitor: NetworkChangeMonitoring, @unchecked Sendable {
    private final class CallbackBox {
        let callback: @Sendable () -> Void
        init(callback: @escaping @Sendable () -> Void) { self.callback = callback }
    }

    private let queue = DispatchQueue(label: "com.egressguard.network-change-monitor")
    private let pathMonitor = NWPathMonitor()
    private let gate = NetworkChangeGate()
    private var dynamicStore: SCDynamicStore?
    private var callbackBox: CallbackBox?
    private var started = false

    func start(handler: @escaping @Sendable () -> Void) {
        guard !started else { return }
        started = true

        let emit: @Sendable () -> Void = { [gate] in
            Task {
                guard await gate.shouldTrigger() else { return }
                handler()
            }
        }

        pathMonitor.pathUpdateHandler = { _ in emit() }
        pathMonitor.start(queue: queue)

        let box = CallbackBox(callback: emit)
        callbackBox = box
        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(box).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        guard let store = SCDynamicStoreCreate(nil, "EgressGuard.NetworkChangeMonitor" as CFString, { _, _, info in
            guard let info else { return }
            Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue().callback()
        }, &context) else { return }

        dynamicStore = store
        let proxyKey = SCDynamicStoreKeyCreateProxies(nil)
        let patterns = [
            "State:/Network/Global/IPv4",
            "State:/Network/Global/IPv6",
            "State:/Network/Global/DNS",
            "State:/Network/Service/.*/IPv4",
            "State:/Network/Service/.*/Interface"
        ] as CFArray
        _ = SCDynamicStoreSetNotificationKeys(store, [proxyKey] as CFArray, patterns)
        _ = SCDynamicStoreSetDispatchQueue(store, queue)
    }

    func stop() {
        pathMonitor.cancel()
        if let dynamicStore { SCDynamicStoreSetDispatchQueue(dynamicStore, nil) }
        dynamicStore = nil
        callbackBox = nil
        started = false
    }
}
