import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var controller: FanController
    @EnvironmentObject private var helper: HelperManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            fansSection
            Divider()
            sensorsSection
            if !controller.presets.isEmpty {
                Divider()
                presetsSection
            }
            if !helper.isReady {
                Divider()
                helperNotice
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
    }

    private var fansSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Fans")).font(.headline)
            if controller.fans.isEmpty {
                Text(controller.smcError ?? L("No fans detected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(controller.fans) { fan in
                HStack {
                    Text(fan.name)
                    Spacer()
                    Text(LF("%ld rpm", Int(fan.actualRPM.rounded())))
                        .monospacedDigit()
                    Text(modeBadge(for: fan))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                .font(.callout)
            }
        }
    }

    private var sensorsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Sensor temperatures")).font(.headline)
            ForEach(controller.sensorGroups.filter { $0.category != .other }) { group in
                HStack {
                    Text(group.category.title)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "%.0f°C", group.maximum))
                        .monospacedDigit()
                }
                .font(.callout)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Presets")).font(.headline)
            ForEach(controller.presets) { preset in
                Button(preset.name) {
                    controller.applyPreset(preset)
                }
                .buttonStyle(.plain)
                .font(.callout)
            }
            Button(L("All fans to Auto")) {
                controller.setAllAuto()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var helperNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L("Fan control inactive"), systemImage: "exclamationmark.triangle")
                .font(.callout)
            Text(helper.statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Button(L("Open OpenFan…")) {
                openWindow(id: WindowID.main)
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button(L("Quit")) {
                NSApp.terminate(nil)
            }
        }
        .font(.callout)
    }

    private func modeBadge(for fan: FanSnapshot) -> String {
        switch controller.mode(for: fan.id) {
        case .auto: return L("Auto")
        case .constant(let rpm): return LF("Const %ld", Int(rpm))
        case .sensor(let key, _, _): return LF("Sensor %@", key)
        }
    }
}
