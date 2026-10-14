import Foundation

enum SensorCategory: String, CaseIterable, Identifiable, Codable {
    case cpu
    case gpu
    case memory
    case storage
    case battery
    case ambient
    case wireless
    case power
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return L("CPU")
        case .gpu: return L("GPU")
        case .memory: return L("Memory")
        case .storage: return L("Storage")
        case .battery: return L("Battery")
        case .ambient: return L("Ambient / Enclosure")
        case .wireless: return L("Wireless")
        case .power: return L("Power")
        case .other: return L("Other")
        }
    }
}

struct SensorReading: Identifiable, Equatable {
    let key: String
    let name: String
    let category: SensorCategory
    let celsius: Double
    let variant: Character?
    let isPrimary: Bool

    var id: String { key }

    var displayName: String {
        if let variant {
            return "\(name) (\(variant))"
        }
        return name
    }
}

struct SensorGroup: Identifiable {
    let category: SensorCategory
    let sensors: [SensorReading]

    var id: SensorCategory { category }
    var average: Double { sensors.map(\.celsius).reduce(0, +) / Double(max(1, sensors.count)) }
    var maximum: Double { sensors.map(\.celsius).max() ?? 0 }
    var hottest: SensorReading? { sensors.max { $0.celsius < $1.celsius } }
}

struct SensorKeyPlan {
    let keys: [String]
    let primaryKeys: Set<String>
    let variantKeys: Set<String>

    static let empty = SensorKeyPlan(keys: [], primaryKeys: [], variantKeys: [])
}

enum SMCSensors {
    private static let smc = SMCConnection.shared
    private static let variantSuffixes: Set<Character> = ["a", "b", "x", "z"]
    private static let variantPriority: [Character] = ["z", "b", "x", "a"]

    static let preferredCPUKey = "TCMz"

    private static let exactNames: [String: String] = [
        "TC0P": "CPU Proximity",
        "TC0D": "CPU Die",
        "TC0E": "CPU Package",
        "TC0F": "CPU Package (Filtered)",
        "TC0C": "CPU Core 1",
        "TC1C": "CPU Core 2",
        "TC2C": "CPU Core 3",
        "TC3C": "CPU Core 4",
        "TC4C": "CPU Core 5",
        "TC5C": "CPU Core 6",
        "TC6C": "CPU Core 7",
        "TC7C": "CPU Core 8",
        "TCGC": "CPU Integrated GPU",
        "TCXC": "CPU PECI",
        "TCHP": "CPU Heat Pipe / Proximity",
        "TG0P": "GPU Proximity",
        "TG0D": "GPU Die",
        "TG0H": "GPU Heatsink",
        "TH0P": "Drive Bay",
        "TH0T": "NAND Storage",
        "TH0x": "NAND Storage (peak)",
        "Th0H": "Heatsink 1",
        "Th1H": "Heatsink 2",
        "TM0P": "Memory Proximity",
        "TM0S": "Memory Slot",
        "TMVR": "Memory Voltage Regulator",
        "TA0P": "Ambient",
        "TA1P": "Ambient 2",
        "TB0T": "Battery",
        "TB1T": "Battery Cell 1",
        "TB2T": "Battery Cell 2",
        "TW0P": "Wireless Module",
        "Ts0P": "Palm Rest",
        "Ts1P": "Palm Rest 2",
        "Ts0S": "Top Case",
        "TPCD": "Platform Controller Hub",
        "TPMP": "Power Manager (PMU)",
        "TPSP": "Power Supply",
        "TSCD": "System Controller",
        "TIOP": "I/O Board",
        "TL0P": "Display",
        "TN0P": "Northbridge",
        "TO0P": "Optical Drive",
        "TI0P": "Thunderbolt",
        "TaLP": "Airflow Left",
        "TaRF": "Airflow Right",
        "TVA0": "Virtual Sensor A0",
        "TVD0": "Virtual Sensor D0",
        "TVS0": "Virtual Sensor S0",
        "TVS1": "Virtual Sensor S1",
        "TVSx": "Virtual Sensor S (peak)",
        "Tp09": "CPU Performance Core 1",
        "Tp0T": "CPU Performance Core 2",
        "Tp01": "CPU Performance Core 3",
        "Tp05": "CPU Performance Core 4",
        "Tp0X": "CPU Efficiency Core 1",
        "Tp0b": "CPU Efficiency Core 2",
        "Tp0L": "CPU Efficiency Core 3",
        "Tp0P": "CPU Efficiency Core 4",
        "Tg05": "GPU Cluster 1",
        "Tg0D": "GPU Cluster 2",
        "Tg0L": "GPU Cluster 3",
        "Tg0T": "GPU Cluster 4",
    ]

    private static let baseNames: [String: String] = [
        "TCM": "CPU (maximum)",
        "Tp2": "CPU Die Zone 2",
        "Tp3": "CPU Die Zone 3",
        "Tp4": "CPU Die Zone 4",
        "Tp5": "CPU Die Zone 5",
        "Tp6": "CPU Die Zone 6",
        "Tp7": "CPU Die Zone 7",
        "Tp8": "CPU Die Zone 8",
        "Tp9": "CPU Die Zone 9",
        "Te0": "SoC Zone E0",
        "Te1": "SoC Zone E1",
        "Te2": "SoC Zone E2",
        "Te3": "SoC Zone E3",
        "Tc0": "SoC Zone C0",
        "Tc7": "SoC Zone C7",
        "Tc8": "SoC Zone C8",
        "Tc9": "SoC Zone C9",
        "Tca": "SoC Zone CA",
        "Th0": "Thermal Zone H0",
        "Th1": "Thermal Zone H1",
        "Th2": "Thermal Zone H2",
        "Ts0": "Skin Sensor 0",
        "Ts1": "Skin Sensor 1",
        "Ts2": "Skin Sensor 2",
        "Ts5": "Skin Sensor 5",
        "Ta1": "Ambient Estimate",
    ]

    static func category(for key: String) -> SensorCategory {
        switch key {
        case "TPMP", "TPSP", "TMVR": return .power
        case "TSCD", "TIOP": return .other
        default: break
        }
        let prefix = String(key.prefix(2))
        switch prefix {
        case "Tp", "TC", "Tc", "Te": return .cpu
        case "Tg", "TG": return .gpu
        case "Tm", "TM": return .memory
        case "TH", "TN", "Tn": return .storage
        case "TB", "Tb": return .battery
        case "TA", "Ta", "Ts", "TS", "TL", "Tl", "Th": return .ambient
        case "TW", "Tw": return .wireless
        case "TV": return .other
        default: return .other
        }
    }

    static func baseName(for key: String, hasVariants: Bool) -> String {
        if let exact = exactNames[key] {
            return exact
        }
        let base = String(key.prefix(3))
        if hasVariants, let name = baseNames[base] {
            return name
        }
        let label = hasVariants ? base : key
        switch category(for: key) {
        case .cpu: return "CPU \(label)"
        case .gpu: return "GPU \(label)"
        case .memory: return "Memory \(label)"
        case .storage: return "Storage \(label)"
        case .battery: return "Battery \(label)"
        case .ambient: return "Enclosure \(label)"
        case .wireless: return "Wireless \(label)"
        case .power: return "Power \(label)"
        case .other: return label
        }
    }

    static func discover() -> SensorKeyPlan {
        guard let allKeys = try? smc.allKeys() else { return .empty }
        var keys: [String] = []
        for key in allKeys where key.hasPrefix("T") {
            guard let info = try? smc.info(key) else { continue }
            let isTemperatureType = info.type == "flt " || info.type.hasPrefix("sp")
            guard isTemperatureType else { continue }
            guard let value = try? smc.readDouble(key) else { continue }
            guard value > 1, value < 125 else { continue }
            keys.append(key)
        }
        keys.sort()

        var families: [String: [String]] = [:]
        for key in keys {
            guard key.count == 4, let last = key.last, variantSuffixes.contains(last) else { continue }
            families[String(key.prefix(3)), default: []].append(key)
        }

        var variantKeys: Set<String> = []
        var primaryKeys: Set<String> = []
        for (base, members) in families where members.count >= 2 {
            variantKeys.formUnion(members)
            let chosen = variantPriority
                .map { base + String($0) }
                .first { members.contains($0) } ?? members[0]
            primaryKeys.insert(chosen)
        }
        for key in keys where !variantKeys.contains(key) {
            primaryKeys.insert(key)
        }
        return SensorKeyPlan(keys: keys, primaryKeys: primaryKeys, variantKeys: variantKeys)
    }

    static func read(_ plan: SensorKeyPlan) -> [SensorReading] {
        plan.keys.compactMap { key in
            guard let value = try? smc.readDouble(key), value > -40, value < 150 else { return nil }
            let hasVariants = plan.variantKeys.contains(key)
            return SensorReading(
                key: key,
                name: baseName(for: key, hasVariants: hasVariants),
                category: category(for: key),
                celsius: value,
                variant: hasVariants ? key.last : nil,
                isPrimary: plan.primaryKeys.contains(key)
            )
        }
    }

    static func grouped(_ sensors: [SensorReading]) -> [SensorGroup] {
        SensorCategory.allCases.compactMap { category in
            let members = sensors.filter { $0.category == category }.sorted { $0.celsius > $1.celsius }
            return members.isEmpty ? nil : SensorGroup(category: category, sensors: members)
        }
    }

    static func exportText(_ sensors: [SensorReading]) -> String {
        sensors.sorted { $0.key < $1.key }
            .map { "\($0.key)\t\($0.displayName)\t\($0.category.rawValue)\t\(String(format: "%.1f", $0.celsius))" }
            .joined(separator: "\n")
    }
}
