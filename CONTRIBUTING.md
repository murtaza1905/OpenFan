# Contributing to OpenFan

Thank you for taking the time to contribute. Bug reports, feature ideas, documentation fixes and code are all welcome.

## Reporting a bug

- Open an issue with the **Bug report** template.
- Include your macOS version, whether the Mac is Intel or Apple Silicon, the OpenFan version (shown in the About window) and the exact steps to reproduce.
- For fan or sensor problems, include the exact Mac model (for example "MacBook Pro 16-inch, 2019" or "Mac mini M2 Pro"), the helper status shown in Settings and, if fans do not react, the output of `log stream --predicate 'subsystem == "com.muratonurcu.OpenFan.helper"'` while you change a speed. The **Copy list** button on the Sensors tab copies every SMC key the app sees.

## Suggesting a feature

- Open an issue with the **Feature request** template.
- Describe the problem you are trying to solve before the solution you have in mind.

## Development setup

Xcode 15 or later. XcodeGen is downloaded into `build/tools/` automatically when it is not installed; Homebrew is not required.

```bash
git clone https://github.com/murtaza1905/OpenFan.git
cd OpenFan
./scripts/build.sh          # build/OpenFan.app (universal)
./scripts/install.sh        # build, install to /Applications and launch
```

The Xcode project is generated from `project.yml`; it is not committed. To work in Xcode run `./scripts/build.sh` once (or `xcodegen generate`) and open `OpenFan.xcodeproj`. The app has two targets: the `OpenFan` app and the `openfan-helper` launchd daemon embedded in the bundle; both share `Sources/Shared` and the C SMC layer in `Sources/SMC`. Changing fan speeds requires the helper, so test fan writes on real hardware — the helper must be reinstalled from Settings after every rebuild that changes it.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request focused on one change.
3. Make sure the project builds with `./scripts/build.sh` — the CI workflow runs the same check on every pull request.
4. Add a line to the **Unreleased** section of `CHANGELOG.md`.
5. Open the pull request; the template lists what to include.

## Code style

- Swift, following Apple's API Design Guidelines; four-space indentation; no trailing whitespace.
- No new third-party dependencies without prior discussion in an issue.
- Every user-facing string goes through the localization layer (`L("…")` / `LF("…")` and `Localizable.xcstrings`) and must be provided in both English and Turkish.
- Shell scripts use `set -euo pipefail` and must run on a clean Mac with only Xcode installed.

## Release process (maintainers)

1. Bump the version (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`) and move the **Unreleased** notes in `CHANGELOG.md` under the new version heading.
2. Commit, push to `main` and wait for CI to pass.
3. Tag the commit and push the tag:

   ```bash
   git tag v<version>
   git push origin v<version>
   ```

4. The **Release** workflow builds a universal (Apple Silicon + Intel) app, packages the `.dmg` and `.zip`, writes `SHA256SUMS.txt` and publishes the GitHub Release using the matching `CHANGELOG.md` section as release notes.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
