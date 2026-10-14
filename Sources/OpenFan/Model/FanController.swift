import Foundation
import AppKit
import ServiceManagement

@MainActor
final class FanController: ObservableObject {
    static let shared = FanController()

    @Published private(set) var fans: [FanSnapshot] = []
    @Published private(set) var sensors: [SensorReading] = []
    @Published private(set) var smcError: String?
    @Published private(set) var controlError: String?
    @Published private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    @Published var modes: [Int: FanControlMode] {
        didSet {
            PersistentStore.save(modes, key: PersistentStore.Key.modes)
            applyControl()
        }
    }

    @Published var presets: [Preset] {
        didSet { PersistentStore.save(presets, key: PersistentStore.Key.presets) }
    }

    @Published var settings: AppSettings {
        didSet {
            PersistentStore.save(settings, key: PersistentStore.Key.settings)
            if oldValue.pollInterval != settings.pollInterval {
                startTimer()
            }
            if oldValue.showDockIcon != settings.showDockIcon {
                applyDockPolicy()
            }
        }
    }

    let helper = HelperManager.shared

    private var sensorPlan: SensorKeyPlan = .empty
    private var timer: Timer?
    private var lastSentRPM: [Int: Double] = [:]
    private var lastSentAt: [Int: Date] = [:]
    private var forcedFans: Set<Int> = []
    private var started = false

    private let resendInterval: TimeInterval = 30
    private let rpmDeadband: Double = 20

    private init() {
        modes = PersistentStore.load([Int: FanControlMode].self, key: PersistentStore.Key.modes) ?? [:]
        presets = PersistentStore.load([Preset].self, key: PersistentStore.Key.presets) ?? []
        settings = PersistentStore.load(AppSettings.self, key: PersistentStore.Key.settings) ?? AppSettings()
    }

    func start() {
        guard !started else { return }
        started = true

        do {
            try SMCConnection.shared.open()
            smcError = nil
        } catch {
            smcError = error.localizedDescription
        }

        applyDockPolicy()
        helper.refreshStatus()
        refreshSensorList()

        if let presetID = settings.applyOnLaunchPresetID,
           let preset = presets.first(where: { $0.id == presetID }) {
            modes = preset.modes
        }

        startTimer()
        poll()
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    func refreshSensorList() {
        Task.detached(priority: .utility) { [weak self] in
            let plan = SMCSensors.discover()
            await self?.updateSensorPlan(plan)
        }
    }

    private func updateSensorPlan(_ plan: SensorKeyPlan) {
        sensorPlan = plan
        poll()
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = max(1, min(30, settings.pollInterval))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        let plan = sensorPlan
        Task.detached(priority: .utility) { [weak self] in
            let count = SMCFans.count()
            let fans = (0..<count).compactMap { SMCFans.snapshot($0) }
            let sensors = SMCSensors.read(plan)
            await self?.update(fans: fans, sensors: sensors)
        }
    }

    private func update(fans newFans: [FanSnapshot], sensors newSensors: [SensorReading]) {
        if fans != newFans { fans = newFans }
        if sensors != newSensors { sensors = newSensors }
        if helper.status != .enabled {
            helper.refreshStatus()
        }
        applyControl()
    }

    func mode(for fanIndex: Int) -> FanControlMode {
        modes[fanIndex] ?? .auto
    }

    func setMode(_ mode: FanControlMode, for fanIndex: Int) {
        if case .auto = mode {
            modes.removeValue(forKey: fanIndex)
        } else {
            modes[fanIndex] = mode
        }
    }

    func setAllAuto() {
        modes = [:]
    }

    func targetRPM(for fan: FanSnapshot) -> Double? {
        switch mode(for: fan.id) {
        case .auto:
            return nil
        case .constant(let rpm):
            return clamp(rpm, to: fan)
        case .sensor(let key, let minTemp, let maxTemp):
            guard let reading = sensors.first(where: { $0.key == key }) else { return nil }
            return interpolate(temperature: reading.celsius, minTemp: minTemp, maxTemp: maxTemp, fan: fan)
        }
    }

    private func applyControl() {
        guard helper.isReady else { return }
        for fan in fans {
            if let target = targetRPM(for: fan) {
                send(target, to: fan)
            } else if forcedFans.contains(fan.id) {
                releaseFan(fan.id)
            }
        }
    }

    private func send(_ rpm: Double, to fan: FanSnapshot) {
        let now = Date()
        if forcedFans.contains(fan.id),
           let last = lastSentRPM[fan.id],
           let sentAt = lastSentAt[fan.id],
           abs(last - rpm) < rpmDeadband,
           now.timeIntervalSince(sentAt) < resendInterval {
            return
        }
        lastSentRPM[fan.id] = rpm
        lastSentAt[fan.id] = now
        forcedFans.insert(fan.id)
        helper.setFanTarget(fan.id, rpm: rpm) { [weak self] error in
            self?.controlError = error
        }
    }

    private func releaseFan(_ index: Int) {
        forcedFans.remove(index)
        lastSentRPM.removeValue(forKey: index)
        lastSentAt.removeValue(forKey: index)
        helper.setFanAuto(index) { [weak self] error in
            self?.controlError = error
        }
    }

    func resetAllToAutoBlocking() {
        forcedFans.removeAll()
        lastSentRPM.removeAll()
        lastSentAt.removeAll()
        helper.setAllAutoBlocking()
    }

    private func clamp(_ rpm: Double, to fan: FanSnapshot) -> Double {
        guard fan.hasValidRange else { return rpm }
        return min(max(rpm, fan.minRPM), fan.maxRPM)
    }

    private func interpolate(temperature: Double, minTemp: Double, maxTemp: Double, fan: FanSnapshot) -> Double {
        let low = fan.hasValidRange ? fan.minRPM : 0
        let high = fan.hasValidRange ? fan.maxRPM : fan.actualRPM
        guard maxTemp > minTemp else { return high }
        if temperature <= minTemp { return low }
        if temperature >= maxTemp { return high }
        let ratio = (temperature - minTemp) / (maxTemp - minTemp)
        return low + (high - low) * ratio
    }

    func saveCurrentAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let index = presets.firstIndex(where: { $0.name == trimmed }) {
            presets[index].modes = modes
        } else {
            presets.append(Preset(name: trimmed, modes: modes))
        }
    }

    func applyPreset(_ preset: Preset) {
        modes = preset.modes
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        if settings.applyOnLaunchPresetID == preset.id {
            settings.applyOnLaunchPresetID = nil
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            controlError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var visibleSensors: [SensorReading] {
        settings.showAllSensors ? sensors : sensors.filter(\.isPrimary)
    }

    var sensorGroups: [SensorGroup] {
        SMCSensors.grouped(visibleSensors)
    }

    var menuBarSensor: SensorReading? {
        if let key = settings.menuBarSensorKey, let reading = sensors.first(where: { $0.key == key }) {
            return reading
        }
        if let cpuMax = sensors.first(where: { $0.key == SMCSensors.preferredCPUKey }) {
            return cpuMax
        }
        if let cpu = SMCSensors.grouped(sensors).first(where: { $0.category == .cpu })?.hottest {
            return cpu
        }
        return sensors.max { $0.celsius < $1.celsius }
    }

    var menuBarFan: FanSnapshot? {
        if let index = settings.menuBarFanIndex, let fan = fans.first(where: { $0.id == index }) {
            return fan
        }
        return fans.first
    }

    var menuBarTitle: String {
        var parts: [String] = []
        if settings.showTempInMenuBar, let sensor = menuBarSensor {
            parts.append("\(Int(sensor.celsius.rounded()))°")
        }
        if settings.showRPMInMenuBar, let fan = menuBarFan {
            parts.append("\(Int(fan.actualRPM.rounded())) rpm")
        }
        return parts.isEmpty ? "OpenFan" : parts.joined(separator: "  ")
    }
}
