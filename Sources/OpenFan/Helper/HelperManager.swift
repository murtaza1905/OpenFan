import Foundation
import ServiceManagement

@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var helperVersion: String?
    @Published private(set) var lastError: String?

    private let service = SMAppService.daemon(plistName: openFanHelperPlistName)
    private var connection: NSXPCConnection?

    private init() {
        status = service.status
    }

    var isReady: Bool { status == .enabled }

    var statusDescription: String {
        switch status {
        case .notRegistered: return L("Not installed")
        case .enabled: return helperVersion.map { LF("Installed and running (v%@)", $0) } ?? L("Installed")
        case .requiresApproval: return L("Waiting for approval in System Settings → Login Items")
        case .notFound: return L("Helper not found inside the app bundle")
        @unknown default: return L("Unknown")
        }
    }

    func refreshStatus() {
        status = service.status
        if status == .enabled {
            ping()
        } else {
            helperVersion = nil
        }
    }

    func install() {
        lastError = nil
        do {
            try service.register()
        } catch {
            lastError = error.localizedDescription
        }
        refreshStatus()
    }

    func uninstall() {
        lastError = nil
        connection?.invalidate()
        connection = nil
        do {
            try service.unregister()
        } catch {
            lastError = error.localizedDescription
        }
        refreshStatus()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func ping() {
        guard let proxy = proxy(onError: { [weak self] message in
            Task { @MainActor in self?.lastError = message }
        }) else { return }
        proxy.version { [weak self] version in
            Task { @MainActor in
                self?.helperVersion = version
                self?.lastError = nil
            }
        }
    }

    func setFanTarget(_ index: Int, rpm: Double, completion: @escaping @MainActor (String?) -> Void) {
        guard let proxy = proxy(onError: { message in Task { @MainActor in completion(message) } }) else {
            completion(L("Helper is not available"))
            return
        }
        proxy.setFanTarget(index: index, rpm: rpm) { error in
            Task { @MainActor in completion(error) }
        }
    }

    func setFanAuto(_ index: Int, completion: @escaping @MainActor (String?) -> Void) {
        guard let proxy = proxy(onError: { message in Task { @MainActor in completion(message) } }) else {
            completion(L("Helper is not available"))
            return
        }
        proxy.setFanAuto(index: index) { error in
            Task { @MainActor in completion(error) }
        }
    }

    func setAllAuto(completion: @escaping @MainActor (String?) -> Void) {
        guard let proxy = proxy(onError: { message in Task { @MainActor in completion(message) } }) else {
            completion(L("Helper is not available"))
            return
        }
        proxy.setAllAuto { error in
            Task { @MainActor in completion(error) }
        }
    }

    func setAllAutoBlocking() {
        guard isReady, let connection = ensureConnection() else { return }
        let proxy = connection.synchronousRemoteObjectProxyWithErrorHandler { _ in } as? OpenFanHelperProtocol
        proxy?.setAllAuto { _ in }
    }

    private func proxy(onError: @escaping (String) -> Void) -> OpenFanHelperProtocol? {
        guard isReady, let connection = ensureConnection() else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { error in
            onError(error.localizedDescription)
        } as? OpenFanHelperProtocol
    }

    private func ensureConnection() -> NSXPCConnection? {
        if let existing = connection {
            return existing
        }
        let newConnection = NSXPCConnection(machServiceName: openFanHelperMachServiceName, options: .privileged)
        newConnection.remoteObjectInterface = NSXPCInterface(with: OpenFanHelperProtocol.self)
        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        newConnection.resume()
        connection = newConnection
        return newConnection
    }
}
