# Privacy Policy

**OpenFan** — last updated 25 October 2026

OpenFan is a free, open-source macOS application developed by Murat Onurcu. This policy describes what the application does with data on your Mac.

## Summary

OpenFan does not collect, store, transmit or share any personal data. It has no user accounts, no analytics, no advertising, no crash reporting service and no network access at runtime.

## Data stored on your Mac

- Fan modes, presets and settings in the application's user defaults (`com.muratonurcu.OpenFan`). They can be removed with `scripts/uninstall.sh` or `defaults delete com.muratonurcu.OpenFan`.
- Temperature and fan readings are kept in memory while the app runs and are not written to disk. The **Copy list** button on the Sensors tab copies the current readings to the clipboard only when you click it.
- The privileged helper writes short diagnostic messages to the unified system log (`os_log`, subsystem `com.muratonurcu.OpenFan.helper`); they contain fan indices and error text, never personal data, and never leave the Mac.

All of this stays on your Mac. Nothing is uploaded anywhere.

## Data that leaves your Mac

None. OpenFan never opens a network connection. It does not check for updates; new versions are announced only on the GitHub Releases page.

## Permissions

- **Login Items & Extensions** approval for the privileged helper (`openfan-helper`), required only to change fan speeds. Reading temperatures and fan speeds works without it.
- Optional **Launch at login** (`SMAppService`), off by default.

No Accessibility, Screen Recording, Full Disk Access, location, camera, microphone or notification permissions are used.

## Third-party components

None. OpenFan contains no third-party code, SDKs or services; the SMC access layer is written for this project.

## Children's privacy

OpenFan does not collect data from anyone, including children.

## Changes to this policy

Changes are recorded in this file and in `CHANGELOG.md`. The version history of this document is available in the repository.

## Contact

Murat Onurcu — muratonurcu@outlook.com
