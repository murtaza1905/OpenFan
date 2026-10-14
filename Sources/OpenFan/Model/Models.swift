import Foundation

enum FanControlMode: Codable, Equatable, Hashable {
    case auto
    case constant(rpm: Double)
    case sensor(key: String, minTemp: Double, maxTemp: Double)

    var kind: FanControlKind {
        switch self {
        case .auto: return .auto
        case .constant: return .constant
        case .sensor: return .sensor
        }
    }
}

enum FanControlKind: String, CaseIterable, Identifiable {
    case auto
    case constant
    case sensor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return L("Auto (system)")
        case .constant: return L("Constant RPM")
        case .sensor: return L("Sensor-based")
        }
    }
}

struct Preset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var modes: [Int: FanControlMode]
}

struct AppSettings: Codable, Equatable {
    var pollInterval: Double = 2
    var menuBarSensorKey: String? = nil
    var menuBarFanIndex: Int? = 0
    var showTempInMenuBar: Bool = true
    var showRPMInMenuBar: Bool = true
    var applyOnLaunchPresetID: UUID? = nil
    var resetToAutoOnQuit: Bool = true
    var showDockIcon: Bool = true
    var showAllSensors: Bool = false
}

enum PersistentStore {
    private static let defaults = UserDefaults.standard

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    enum Key {
        static let modes = "openfan.modes"
        static let presets = "openfan.presets"
        static let settings = "openfan.settings"
    }
}
