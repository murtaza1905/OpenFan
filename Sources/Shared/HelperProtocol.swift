import Foundation

let openFanHelperMachServiceName = "com.muratonurcu.OpenFan.helper"
let openFanHelperPlistName = "com.muratonurcu.OpenFan.helper.plist"
let openFanHelperVersion = "1.1.0"

/// Mach service and launchd label used by OpenFan 1.3.x and earlier.
/// Kept only so that install/uninstall scripts and release notes can refer to it.
let openFanLegacyHelperLabel = "com.openfan.helper"

@objc(OpenFanHelperProtocol)
protocol OpenFanHelperProtocol {
    func version(reply: @escaping (String) -> Void)
    func setFanTarget(index: Int, rpm: Double, reply: @escaping (String?) -> Void)
    func setFanAuto(index: Int, reply: @escaping (String?) -> Void)
    func setAllAuto(reply: @escaping (String?) -> Void)
}
