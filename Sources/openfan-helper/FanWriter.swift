import Foundation

enum FanWriter {
    private static let smc = SMCConnection.shared
    private static let lock = NSLock()

    static func fanCount() -> Int {
        guard let count = try? smc.readDouble("FNum") else { return 0 }
        return max(0, Int(count))
    }

    static func setTarget(index: Int, rpm: Double) throws {
        lock.lock()
        defer { lock.unlock() }

        guard index >= 0, index < fanCount() else {
            throw SMCError.keyNotFound("F\(index)Tg")
        }

        let targetKey = "F\(index)Tg"
        let modeKey = "F\(index)Md"
        let targetInfo = try smc.info(targetKey)

        var clamped = rpm
        if let minimum = try? smc.readDouble("F\(index)Mn"), minimum > 0 {
            clamped = max(clamped, minimum)
        }
        if let maximum = try? smc.readDouble("F\(index)Mx"), maximum > 0 {
            clamped = min(clamped, maximum)
        }

        if smc.keyExists(modeKey) {
            try smc.writeDouble(1, to: modeKey)
        } else if smc.keyExists("FS! ") {
            var mask = Int(try smc.readDouble("FS! "))
            mask |= (1 << index)
            try smc.writeDouble(Double(mask), to: "FS! ")
        }

        let bytes = try SMCCodec.encode(clamped, type: targetInfo.type, size: targetInfo.size, key: targetKey)
        try smc.write(targetKey, bytes: bytes)
    }

    static func setAuto(index: Int) throws {
        lock.lock()
        defer { lock.unlock() }

        guard index >= 0, index < fanCount() else {
            throw SMCError.keyNotFound("F\(index)Md")
        }

        let modeKey = "F\(index)Md"
        if smc.keyExists(modeKey) {
            try smc.writeDouble(0, to: modeKey)
        } else if smc.keyExists("FS! ") {
            var mask = Int(try smc.readDouble("FS! "))
            mask &= ~(1 << index)
            try smc.writeDouble(Double(mask), to: "FS! ")
        }
    }

    static func setAllAuto() throws {
        var firstError: Error?
        for index in 0..<fanCount() {
            do {
                try setAuto(index: index)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let error = firstError {
            throw error
        }
    }
}
