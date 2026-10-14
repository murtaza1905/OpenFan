import SwiftUI
import AppKit

struct MainWindow: View {
    @EnvironmentObject private var controller: FanController
    @EnvironmentObject private var helper: HelperManager

    var body: some View {
        TabView {
            FansTab()
                .tabItem { Label(L("Fans"), systemImage: "fan") }
            SensorsTab()
                .tabItem { Label(L("Sensors"), systemImage: "thermometer.medium") }
            PresetsTab()
                .tabItem { Label(L("Presets"), systemImage: "square.stack.3d.up") }
            SettingsTab()
                .tabItem { Label(L("Settings"), systemImage: "gearshape") }
        }
        .padding()
        .onAppear { helper.refreshStatus() }
    }
}

struct FansTab: View {
    @EnvironmentObject private var controller: FanController
    @EnvironmentObject private var helper: HelperManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !helper.isReady {
                HelperBanner()
            }
            if let error = controller.controlError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if controller.fans.isEmpty {
                ContentUnavailableCompat(
                    title: L("No fans detected"),
                    detail: controller.smcError ?? L("This Mac reports no controllable fans.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(controller.fans) { fan in
                            FanRow(fan: fan)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct FanRow: View {
    @EnvironmentObject private var controller: FanController
    let fan: FanSnapshot

    private var mode: Binding<FanControlMode> {
        Binding(
            get: { controller.mode(for: fan.id) },
            set: { controller.setMode($0, for: fan.id) }
        )
    }

    private var kind: Binding<FanControlKind> {
        Binding(
            get: { mode.wrappedValue.kind },
            set: { newKind in
                switch newKind {
                case .auto:
                    mode.wrappedValue = .auto
                case .constant:
                    let start = fan.hasValidRange ? max(fan.minRPM, fan.actualRPM) : fan.actualRPM
                    mode.wrappedValue = .constant(rpm: start.rounded())
                case .sensor:
                    let key = controller.menuBarSensor?.key ?? controller.sensors.first?.key ?? ""
                    mode.wrappedValue = .sensor(key: key, minTemp: 50, maxTemp: 80)
                }
            }
        )
    }

    private var constantRPM: Binding<Double> {
        Binding(
            get: {
                if case .constant(let rpm) = mode.wrappedValue { return rpm }
                return fan.actualRPM
            },
            set: { mode.wrappedValue = .constant(rpm: $0.rounded()) }
        )
    }

    private var sensorKey: Binding<String> {
        Binding(
            get: {
                if case .sensor(let key, _, _) = mode.wrappedValue { return key }
                return ""
            },
            set: { newKey in
                if case .sensor(_, let lo, let hi) = mode.wrappedValue {
                    mode.wrappedValue = .sensor(key: newKey, minTemp: lo, maxTemp: hi)
                }
            }
        )
    }

    private var minTemp: Binding<Double> {
        Binding(
            get: {
                if case .sensor(_, let lo, _) = mode.wrappedValue { return lo }
                return 50
            },
            set: { newValue in
                if case .sensor(let key, _, let hi) = mode.wrappedValue {
                    mode.wrappedValue = .sensor(key: key, minTemp: newValue, maxTemp: max(hi, newValue + 1))
                }
            }
        )
    }

    private var maxTemp: Binding<Double> {
        Binding(
            get: {
                if case .sensor(_, _, let hi) = mode.wrappedValue { return hi }
                return 80
            },
            set: { newValue in
                if case .sensor(let key, let lo, _) = mode.wrappedValue {
                    mode.wrappedValue = .sensor(key: key, minTemp: min(lo, newValue - 1), maxTemp: newValue)
                }
            }
        )
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(fan.name).font(.headline)
                    Spacer()
                    Text(LF("%ld rpm", Int(fan.actualRPM.rounded())))
                        .font(.title3)
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    Text(LF("Range: %ld–%ld rpm", Int(fan.minRPM), Int(fan.maxRPM)))
                    Text(LF("Target: %ld rpm", Int(fan.targetRPM.rounded())))
                    Text(fan.isForced ? L("Manual") : L("System"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Picker(L("Control"), selection: kind) {
                    ForEach(FanControlKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch mode.wrappedValue.kind {
                case .auto:
                    Text(L("The system controls this fan."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .constant:
                    HStack {
                        Slider(
                            value: constantRPM,
                            in: sliderRange,
                            step: 10
                        )
                        TextField(L("RPM"), value: constantRPM, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text(L("rpm"))
                    }
                case .sensor:
                    VStack(alignment: .leading, spacing: 8) {
                        SensorPicker(title: L("Sensor"), selection: sensorKey)
                        HStack(spacing: 12) {
                            Text(L("Min RPM at"))
                            TextField(L("°C"), value: minTemp, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text(L("°C"))
                            Text(L("Max RPM at"))
                            TextField(L("°C"), value: maxTemp, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text(L("°C"))
                            Spacer()
                            if let target = controller.targetRPM(for: fan) {
                                Text(LF("→ %ld rpm", Int(target.rounded())))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private var sliderRange: ClosedRange<Double> {
        if fan.hasValidRange {
            return fan.minRPM...fan.maxRPM
        }
        return 0...max(fan.actualRPM, 6000)
    }
}

struct SensorsTab: View {
    @EnvironmentObject private var controller: FanController
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LF("%ld sensors", controller.visibleSensors.count))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(L("Show all sensors"), isOn: $controller.settings.showAllSensors)
                    .toggleStyle(.switch)
                Button(copied ? L("Copied") : L("Copy list")) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(SMCSensors.exportText(controller.sensors), forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
                Button(L("Rescan")) { controller.refreshSensorList() }
            }

            if controller.settings.showAllSensors {
                Table(controller.sensors.sorted { $0.celsius > $1.celsius }) {
                    TableColumn(L("Key"), value: \.key).width(60)
                    TableColumn(L("Category")) { sensor in
                        Text(sensor.category.title)
                    }
                    .width(120)
                    TableColumn(L("Name"), value: \.displayName)
                    TableColumn(L("°C")) { sensor in
                        Text(String(format: "%.1f", sensor.celsius)).monospacedDigit()
                    }
                    .width(70)
                }
            } else {
                List {
                    ForEach(controller.sensorGroups) { group in
                        DisclosureGroup {
                            ForEach(group.sensors.prefix(12)) { sensor in
                                HStack {
                                    Text(sensor.displayName)
                                    Spacer()
                                    Text(String(format: "%.1f°", sensor.celsius)).monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.callout)
                            }
                            if group.sensors.count > 12 {
                                Text(LF("%ld sensors", group.sensors.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            HStack {
                                Text(group.category.title).font(.headline)
                                Spacer()
                                Text(LF("avg %.0f° · max %.0f°", group.average, group.maximum))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SensorPicker: View {
    @EnvironmentObject private var controller: FanController
    let title: String
    @Binding var selection: String
    var includeAutomatic: Bool = false

    var body: some View {
        Picker(title, selection: $selection) {
            if includeAutomatic {
                Text(L("Automatic (CPU / hottest)")).tag("")
            }
            ForEach(controller.sensorGroups) { group in
                Section(group.category.title) {
                    ForEach(group.sensors) { sensor in
                        Text("\(sensor.displayName)  (\(Int(sensor.celsius.rounded()))°C)").tag(sensor.key)
                    }
                }
            }
        }
    }
}

struct PresetsTab: View {
    @EnvironmentObject private var controller: FanController
    @State private var newPresetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField(L("Preset name"), text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                Button(L("Save current configuration")) {
                    controller.saveCurrentAsPreset(named: newPresetName)
                    newPresetName = ""
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if controller.presets.isEmpty {
                ContentUnavailableCompat(
                    title: L("No presets yet"),
                    detail: L("Configure the fans, then save the configuration under a name.")
                )
            } else {
                List {
                    ForEach(controller.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name).font(.headline)
                                Text(summary(for: preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(L("Apply on launch"), isOn: Binding(
                                get: { controller.settings.applyOnLaunchPresetID == preset.id },
                                set: { controller.settings.applyOnLaunchPresetID = $0 ? preset.id : nil }
                            ))
                            .toggleStyle(.checkbox)
                            Button(L("Apply")) { controller.applyPreset(preset) }
                            Button(role: .destructive) {
                                controller.deletePreset(preset)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func summary(for preset: Preset) -> String {
        if preset.modes.isEmpty { return L("All fans: Auto") }
        return preset.modes.keys.sorted().map { index -> String in
            let name = controller.fans.first { $0.id == index }?.name ?? LF("Fan %ld", index + 1)
            switch preset.modes[index] ?? .auto {
            case .auto: return LF("%@: Auto", name)
            case .constant(let rpm): return LF("%@: %ld rpm", name, Int(rpm))
            case .sensor(let key, let lo, let hi): return LF("%@: %@ %ld–%ld°C", name, key, Int(lo), Int(hi))
            }
        }.joined(separator: " · ")
    }
}

struct SettingsTab: View {
    @EnvironmentObject private var controller: FanController
    @EnvironmentObject private var helper: HelperManager

    var body: some View {
        Form {
            Section(L("Privileged helper (required to change fan speeds)")) {
                LabeledContent(L("Status"), value: helper.statusDescription)
                if let error = helper.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    if helper.status == .notRegistered || helper.status == .notFound {
                        Button(L("Install helper")) { helper.install() }
                    }
                    if helper.status == .requiresApproval {
                        Button(L("Open System Settings")) { helper.openSystemSettings() }
                    }
                    if helper.status == .enabled || helper.status == .requiresApproval {
                        Button(L("Remove helper")) { helper.uninstall() }
                    }
                    Button(L("Refresh")) { helper.refreshStatus() }
                }
            }

            Section(L("Startup")) {
                Toggle(L("Launch OpenFan at login"), isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                ))
                Toggle(L("Return fans to Auto when quitting"), isOn: $controller.settings.resetToAutoOnQuit)
            }

            Section(L("Window")) {
                Toggle(L("Show icon in Dock"), isOn: $controller.settings.showDockIcon)
            }

            Section(L("Menu bar")) {
                Toggle(L("Show temperature"), isOn: $controller.settings.showTempInMenuBar)
                SensorPicker(
                    title: L("Temperature sensor"),
                    selection: Binding(
                        get: { controller.settings.menuBarSensorKey ?? "" },
                        set: { controller.settings.menuBarSensorKey = $0.isEmpty ? nil : $0 }
                    ),
                    includeAutomatic: true
                )
                Toggle(L("Show fan speed"), isOn: $controller.settings.showRPMInMenuBar)
                Picker(L("Fan"), selection: Binding(
                    get: { controller.settings.menuBarFanIndex ?? -1 },
                    set: { controller.settings.menuBarFanIndex = $0 < 0 ? nil : $0 }
                )) {
                    Text(L("First fan")).tag(-1)
                    ForEach(controller.fans) { fan in
                        Text(fan.name).tag(fan.id)
                    }
                }
            }

            Section(L("Polling")) {
                Stepper(
                    LF("Refresh every %ld s", Int(controller.settings.pollInterval)),
                    value: $controller.settings.pollInterval,
                    in: 1...30,
                    step: 1
                )
            }
        }
        .formStyle(.grouped)
    }
}

struct HelperBanner: View {
    @EnvironmentObject private var helper: HelperManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Fan control is inactive")).font(.headline)
                Text(helper.statusDescription).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if helper.status == .requiresApproval {
                Button(L("Open System Settings")) { helper.openSystemSettings() }
            } else {
                Button(L("Install helper")) { helper.install() }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ContentUnavailableCompat: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.title3)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
