import Foundation
import os.log

private let log = Logger(subsystem: "com.openfan.helper", category: "xpc")

final class HelperService: NSObject, OpenFanHelperProtocol {
    func version(reply: @escaping (String) -> Void) {
        reply(openFanHelperVersion)
    }

    func setFanTarget(index: Int, rpm: Double, reply: @escaping (String?) -> Void) {
        do {
            try FanWriter.setTarget(index: index, rpm: rpm)
            reply(nil)
        } catch {
            log.error("setFanTarget(\(index), \(rpm)) failed: \(error.localizedDescription, privacy: .public)")
            reply(error.localizedDescription)
        }
    }

    func setFanAuto(index: Int, reply: @escaping (String?) -> Void) {
        do {
            try FanWriter.setAuto(index: index)
            reply(nil)
        } catch {
            log.error("setFanAuto(\(index)) failed: \(error.localizedDescription, privacy: .public)")
            reply(error.localizedDescription)
        }
    }

    func setAllAuto(reply: @escaping (String?) -> Void) {
        do {
            try FanWriter.setAllAuto()
            reply(nil)
        } catch {
            log.error("setAllAuto failed: \(error.localizedDescription, privacy: .public)")
            reply(error.localizedDescription)
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: OpenFanHelperProtocol.self)
        connection.exportedObject = HelperService()
        connection.invalidationHandler = {
            log.info("Client disconnected, restoring automatic fan control")
            try? FanWriter.setAllAuto()
        }
        connection.resume()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: openFanHelperMachServiceName)
listener.delegate = delegate
listener.resume()
log.info("openfan-helper \(openFanHelperVersion, privacy: .public) started")
RunLoop.current.run()
