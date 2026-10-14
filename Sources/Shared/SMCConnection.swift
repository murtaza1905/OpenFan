import Foundation

enum SMCError: Error, LocalizedError {
    case openFailed(Int32)
    case keyNotFound(String)
    case callFailed(String, Int32)
    case unsupportedType(String, String)
    case sizeMismatch(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let code):
            return String(format: NSLocalizedString("Could not open AppleSMC (code %ld).", comment: ""), Int(code))
        case .keyNotFound(let key):
            return String(format: NSLocalizedString("SMC key '%@' not found.", comment: ""), key)
        case .callFailed(let key, let code):
            return String(format: NSLocalizedString("SMC call failed for '%@' (code %ld).", comment: ""), key, Int(code))
        case .unsupportedType(let key, let type):
            return String(format: NSLocalizedString("SMC key '%@' has unsupported type '%@'.", comment: ""), key, type)
        case .sizeMismatch(let key):
            return String(format: NSLocalizedString("SMC key '%@' size mismatch.", comment: ""), key)
        }
    }
}

final class SMCConnection {
    static let shared = SMCConnection()

    struct Value {
        let key: String
        let type: String
        let bytes: [UInt8]
    }

    struct KeyInfo {
        let type: String
        let size: Int
    }

    private let lock = NSLock()
    private var opened = false

    private init() {}

    func open() throws {
        lock.lock()
        defer { lock.unlock() }
        if opened { return }
        let result = smc_open()
        guard result == 0 else { throw SMCError.openFailed(result) }
        opened = true
    }

    func keyExists(_ key: String) -> Bool {
        (try? info(key)) != nil
    }

    func info(_ key: String) throws -> KeyInfo {
        try open()
        lock.lock()
        defer { lock.unlock() }

        var typeBuffer: (CChar, CChar, CChar, CChar, CChar) = (0, 0, 0, 0, 0)
        var size: UInt32 = 0
        let result = withUnsafeMutablePointer(to: &typeBuffer) { pointer -> Int32 in
            pointer.withMemoryRebound(to: CChar.self, capacity: 5) { smc_key_info(key, $0, &size) }
        }
        guard result == 0 else { throw map(result, key: key) }
        let type = withUnsafePointer(to: &typeBuffer) { pointer -> String in
            pointer.withMemoryRebound(to: CChar.self, capacity: 5) { String(cString: $0) }
        }
        return KeyInfo(type: type, size: Int(size))
    }

    func read(_ key: String) throws -> Value {
        try open()
        lock.lock()
        defer { lock.unlock() }

        var raw = smc_value_t()
        let result = smc_read(key, &raw)
        guard result == 0 else { throw map(result, key: key) }

        let type = withUnsafePointer(to: &raw.type) { pointer -> String in
            pointer.withMemoryRebound(to: CChar.self, capacity: 5) { String(cString: $0) }
        }
        let count = Int(raw.size)
        let bytes = withUnsafeBytes(of: &raw.bytes) { Array($0.prefix(count)) }
        return Value(key: key, type: type, bytes: bytes)
    }

    func readDouble(_ key: String) throws -> Double {
        try SMCCodec.double(read(key))
    }

    func write(_ key: String, bytes: [UInt8]) throws {
        try open()
        lock.lock()
        defer { lock.unlock() }

        let result = bytes.withUnsafeBufferPointer { buffer -> Int32 in
            smc_write(key, buffer.baseAddress, UInt32(bytes.count))
        }
        guard result == 0 else { throw map(result, key: key) }
    }

    func writeDouble(_ value: Double, to key: String) throws {
        let keyInfo = try info(key)
        let bytes = try SMCCodec.encode(value, type: keyInfo.type, size: keyInfo.size, key: key)
        try write(key, bytes: bytes)
    }

    func allKeys() throws -> [String] {
        try open()
        lock.lock()
        defer { lock.unlock() }

        var count: UInt32 = 0
        let countResult = smc_key_count(&count)
        guard countResult == 0 else { throw map(countResult, key: "#KEY") }

        var keys: [String] = []
        keys.reserveCapacity(Int(count))
        for index in 0..<count {
            var buffer: (CChar, CChar, CChar, CChar, CChar) = (0, 0, 0, 0, 0)
            let result = withUnsafeMutablePointer(to: &buffer) { pointer -> Int32 in
                pointer.withMemoryRebound(to: CChar.self, capacity: 5) { smc_key_at_index(index, $0) }
            }
            guard result == 0 else { continue }
            let key = withUnsafePointer(to: &buffer) { pointer -> String in
                pointer.withMemoryRebound(to: CChar.self, capacity: 5) { String(cString: $0) }
            }
            if key.count == 4 {
                keys.append(key)
            }
        }
        return keys
    }

    private func map(_ code: Int32, key: String) -> SMCError {
        if code == SMC_ERR_KEY_NOT_FOUND {
            return .keyNotFound(key)
        }
        return .callFailed(key, code)
    }
}

enum SMCCodec {
    static func double(_ value: SMCConnection.Value) throws -> Double {
        let bytes = value.bytes
        let type = value.type

        func bigEndian(_ count: Int) -> UInt64 {
            var result: UInt64 = 0
            for i in 0..<min(count, bytes.count) {
                result = (result << 8) | UInt64(bytes[i])
            }
            return result
        }

        switch type {
        case "flt ":
            guard bytes.count == 4 else { throw SMCError.sizeMismatch(value.key) }
            let bits = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return Double(Float(bitPattern: bits))
        case "ui8 ", "ui16", "ui32", "ui64":
            return Double(bigEndian(bytes.count))
        case "si8 ":
            guard bytes.count == 1 else { throw SMCError.sizeMismatch(value.key) }
            return Double(Int8(bitPattern: bytes[0]))
        case "si16":
            guard bytes.count == 2 else { throw SMCError.sizeMismatch(value.key) }
            return Double(Int16(bitPattern: UInt16(bigEndian(2))))
        case "si32":
            guard bytes.count == 4 else { throw SMCError.sizeMismatch(value.key) }
            return Double(Int32(bitPattern: UInt32(bigEndian(4))))
        case "ioft":
            guard bytes.count == 8 else { throw SMCError.sizeMismatch(value.key) }
            return Double(bigEndian(8)) / 65536.0
        default:
            if type.hasPrefix("fp"), bytes.count == 2, let fraction = fractionBits(type) {
                return Double(bigEndian(2)) / pow(2.0, Double(fraction))
            }
            if type.hasPrefix("sp"), bytes.count == 2, let fraction = fractionBits(type) {
                return Double(Int16(bitPattern: UInt16(bigEndian(2)))) / pow(2.0, Double(fraction))
            }
            throw SMCError.unsupportedType(value.key, type)
        }
    }

    static func encode(_ value: Double, type: String, size: Int, key: String) throws -> [UInt8] {
        switch type {
        case "flt ":
            let bits = Float(value).bitPattern
            return [UInt8(bits & 0xFF), UInt8((bits >> 8) & 0xFF), UInt8((bits >> 16) & 0xFF), UInt8((bits >> 24) & 0xFF)]
        case "ui8 ":
            return [UInt8(clamping: Int(value.rounded()))]
        case "ui16":
            let v = UInt16(clamping: Int(value.rounded()))
            return [UInt8(v >> 8), UInt8(v & 0xFF)]
        case "ui32":
            let v = UInt32(clamping: Int(value.rounded()))
            return [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
        case "si8 ":
            let v = Int8(clamping: Int(value.rounded()))
            return [UInt8(bitPattern: v)]
        case "si16":
            let v = UInt16(bitPattern: Int16(clamping: Int(value.rounded())))
            return [UInt8(v >> 8), UInt8(v & 0xFF)]
        default:
            if type.hasPrefix("fp"), size == 2, let fraction = fractionBits(type) {
                let scaled = UInt16(clamping: Int((value * pow(2.0, Double(fraction))).rounded()))
                return [UInt8(scaled >> 8), UInt8(scaled & 0xFF)]
            }
            if type.hasPrefix("sp"), size == 2, let fraction = fractionBits(type) {
                let scaled = UInt16(bitPattern: Int16(clamping: Int((value * pow(2.0, Double(fraction))).rounded())))
                return [UInt8(scaled >> 8), UInt8(scaled & 0xFF)]
            }
            throw SMCError.unsupportedType(key, type)
        }
    }

    private static func fractionBits(_ type: String) -> Int? {
        guard let last = type.last else { return nil }
        return Int(String(last), radix: 16)
    }
}
