import Foundation

let openFanHelperMachServiceName = "com.openfan.helper"
let openFanHelperPlistName = "com.openfan.helper.plist"
let openFanHelperVersion = "1.0.0"

@objc(OpenFanHelperProtocol)
protocol OpenFanHelperProtocol {
    func version(reply: @escaping (String) -> Void)
    func setFanTarget(index: Int, rpm: Double, reply: @escaping (String?) -> Void)
    func setFanAuto(index: Int, reply: @escaping (String?) -> Void)
    func setAllAuto(reply: @escaping (String?) -> Void)
}
