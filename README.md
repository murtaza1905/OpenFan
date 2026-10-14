# OpenFan

Open-source fan control for Intel and Apple Silicon Macs. One edition, every feature, no restrictions.

OpenFan runs as a regular app with a Dock icon and a settings window, plus a menu bar item (the Dock icon can be turned off in Settings). The menu bar item shows the temperature and fan speed you choose, and lets you take control of each fan individually:

- **Auto** – the system decides (default)
- **Constant RPM** – pin a fan to a fixed speed
- **Sensor-based** – a fan follows a temperature sensor of your choice with a linear curve between a minimum and maximum temperature
- **Presets** – save complete fan configurations, apply them from the menu bar, apply one automatically at launch
- **Sensors** – every temperature sensor the SMC exposes, with readable names
- **Localized** – English and Turkish, following the system language
- **Safety** – fans return to automatic control when the app quits, when the app disconnects from the helper, and targets are always clamped to the fan's hardware range

Written from scratch in Swift + SwiftUI with a small C layer for the SMC. UI in English and Turkish (follows the system language). MIT licensed.

## Download

Prebuilt universal (Intel + Apple Silicon) disk image: **[Releases](https://github.com/murtaza1905/OpenFan/releases/latest)** → `OpenFan-<version>.dmg`. Drag to Applications; on first launch right-click → Open (self-signed). If macOS reports the app as damaged: `xattr -dr com.apple.quarantine /Applications/OpenFan.app`.

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
git clone https://github.com/murtaza1905/OpenFan.git
cd OpenFan
./scripts/build.sh --install
```

`--install` copies the app to `/Applications` and launches it. Without the flag the app is left in `build/OpenFan.app`.

Or generate the project and open it in Xcode:

```bash
xcodegen generate
open OpenFan.xcodeproj
```

Select the `OpenFan` scheme and run. Ad-hoc signing (`-`) is configured by default so it builds without an Apple Developer account. If you have a team, set `DEVELOPMENT_TEAM` in `project.yml`.

## First run

1. Move `OpenFan.app` to `/Applications` (the privileged helper is registered from the app's location, so the app must not move afterwards).
2. Launch OpenFan. The main window opens and a menu bar item appears.
3. **Settings → Install helper**.
4. macOS asks you to allow the background item: **System Settings → General → Login Items & Extensions**, enable **OpenFan**.
5. Back in OpenFan, click **Refresh**. Status should read *Installed and running*.

Reading temperatures and fan speeds never needs the helper; only changing fan speeds does.

## How it works

- **Reading** – `AppleSMC` is opened via IOKit from the app process. Fan keys are `FNum`, `F<n>Ac` (actual), `F<n>Tg` (target), `F<n>Mn`/`F<n>Mx` (range), `F<n>Md` (mode), `F<n>ID` (name). Temperature sensors are discovered by enumerating all SMC keys starting with `T` whose type is `flt` or `sp78`-style and whose value is plausible.
- **Writing** – fan targets require root. `openfan-helper` is a launchd daemon registered with `SMAppService` and reached over XPC. The helper validates the fan index, clamps the target to the hardware range, switches the fan to manual mode and writes the target.
  - Apple Silicon and newer Intel Macs: `F<n>Md = 1` then `F<n>Tg` (float)
  - Older Intel Macs: set bit *n* in `FS!` then `F<n>Tg` (fpe2)
- **Control loop** – the app polls every 1–30 s, computes each fan's target from its mode and resends when the target moves more than 20 rpm or every 30 s.

## Sensors

Apple Silicon Macs expose many SMC temperature keys. OpenFan groups them by category and, by default, shows one reading per sensor family: keys that differ only in an `a`/`b`/`x`/`z` suffix are variants of the same measurement point, and the `z` variant (highest, most responsive) is shown. "Show all sensors" reveals every key. Apple does not document these keys; the names OpenFan assigns to undocumented ones (SoC zones, thermal zones, skin sensors, virtual sensors) are descriptive labels, not official designations. `TCMz`, where present, is the maximum of the CPU die sensors and is used as the default CPU reading.

## Project layout

```
project.yml                     XcodeGen project definition
Sources/SMC/                    C: AppleSMC IOKit access
Sources/Shared/                 Swift: SMC wrapper + codec, XPC protocol (both targets)
Sources/openfan-helper/         Privileged launchd daemon (fan writes)
Sources/OpenFan/                Menu bar app (SwiftUI)
Resources/com.openfan.helper.plist   launchd plist embedded in the app bundle
scripts/install.sh              Build, install to /Applications, launch
scripts/build.sh                Build only
scripts/make-dmg.sh             Universal build + .dmg
scripts/uninstall.sh            Remove app, helper, settings
```

## Troubleshooting

- **Helper status "Not found"** – the plist or helper binary is missing from the bundle. Rebuild; check `OpenFan.app/Contents/Library/LaunchDaemons/` and `Contents/MacOS/openfan-helper`.
- **Status stays "Waiting for approval"** – approve the item in Login Items & Extensions, then click Refresh. If it was approved before but the app moved, click Remove helper, move the app back, Install helper again.
- **Fan does not change speed** – check Fans tab for an error line. Run `log stream --predicate 'subsystem == "com.openfan.helper"'` in Terminal to see helper errors.
- **Helper not responding after an app update** – Remove helper, then Install helper again.
- **No fans** – some Macs (MacBook Air M1/M2) have no fans; sensors still work.

## Security notes

The helper accepts any local XPC client that can reach its Mach service. It only ever writes fan keys for valid fan indices within the hardware range, so the worst case is a fan speed change. Adding a code-signing requirement on the connection (`NSXPCConnection.setCodeSigningRequirement`) is the recommended hardening once the project is signed with a Developer ID.

## License

MIT – see [LICENSE](LICENSE).
