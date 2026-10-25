# Changelog

All notable changes to OpenFan are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.4.0] - 2026-10-25

### Added
- **About OpenFan** in the application menu and in the menu bar popover, opening the standard About window with version, developer contact and source link; **About** section in Settings (English and Turkish).
- Privacy manifest (`PrivacyInfo.xcprivacy`) bundled with the app.
- Continuous integration build on every push and pull request; tag-triggered release workflow that builds the universal app, packages `.dmg` and `.zip`, writes `SHA256SUMS.txt` and publishes the GitHub Release.
- `CONTRIBUTING.md`, `SECURITY.md`, `PRIVACY.md`, issue and pull request templates.

### Changed
- Bundle identifiers are now `com.muratonurcu.OpenFan` (app) and `com.muratonurcu.OpenFan.helper` (privileged helper, launchd label and Mach service); previously `com.openfan.app` / `com.openfan.helper`. Modes, presets and settings are migrated automatically on first launch.
- **Upgrading from 1.3.x:** the old helper stays registered under its old name. Before installing the new one, remove it once in Terminal: `sudo launchctl bootout system/com.openfan.helper` (the install and uninstall scripts do this for you). Then Settings → **Install helper** and approve OpenFan under Login Items & Extensions. If **Launch at login** was on, turn it on again.
- Helper protocol version 1.1.0; helper log subsystem is `com.muratonurcu.OpenFan.helper`.
- `scripts/build.sh` now produces a universal binary and downloads XcodeGen itself when needed; `scripts/make-dmg.sh` writes to `dist/`, lays out the disk image window and sets the volume icon.
- Version and build number are defined once in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
- Application category and copyright string set; LICENSE names the copyright holder; README rewritten (the build instructions previously referred to a non-existent `build.sh --install` option).

## [1.3.1] - 2026-10-18

### Changed
- App icon redrawn on Apple's 824 px icon grid.

## [1.3.0] - 2026-10-14

### Added
- Initial public release: per-fan Auto / Constant RPM / Sensor-based control, presets, SMC temperature sensors with readable names, menu bar item with temperature and fan speed, privileged helper for fan writes, English and Turkish interface.

[Unreleased]: https://github.com/murtaza1905/OpenFan/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/murtaza1905/OpenFan/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/murtaza1905/OpenFan/releases/tag/v1.3.1
[1.3.0]: https://github.com/murtaza1905/OpenFan/commits/main
