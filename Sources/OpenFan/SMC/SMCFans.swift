import Foundation

struct FanSnapshot: Identifiable, Equatable {
    let id: Int
    let name: String
    let minRPM: Double
    let maxRPM: Double
    let actualRPM: Double
    let targetRPM: Double
    let isForced: Bool

    var hasValidRange: Bool { maxRPM > minRPM && maxRPM > 0 }
}

enum SMCFans {
    private static let smc = SMCConnection.shared

    static func count() -> Int {
        guard let value = try? smc.readDouble("FNum") else { return 0 }
        return max(0, min(16, Int(value)))
    }

    static func snapshot(_ index: Int) -> FanSnapshot? {
        guard let actual = try? smc.readDouble("F\(index)Ac") else { return nil }
        let target = (try? smc.readDouble("F\(index)Tg")) ?? actual
        let minimum = (try? smc.readDouble("F\(index)Mn")) ?? 0
        let maximum = (try? smc.readDouble("F\(index)Mx")) ?? 0

        let forced: Bool
        if let mode = try? smc.readDouble("F\(index)Md") {
            forced = mode != 0
        } else if let mask = try? smc.readDouble("FS! ") {
            forced = (Int(mask) >> index) & 1 == 1
        } else {
            forced = false
        }

        return FanSnapshot(
            id: index,
            name: name(for: index),
            minRPM: minimum,
            maxRPM: maximum,
            actualRPM: actual,
            targetRPM: target,
            isForced: forced
        )
    }

    private static func name(for index: Int) -> String {
        if let value = try? smc.read("F\(index)ID"), value.bytes.count >= 16 {
            let nameBytes = value.bytes[4..<16].prefix { $0 != 0 }
            if let text = String(bytes: nameBytes, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
        }
        return LF("Fan %ld", index + 1)
    }
}
