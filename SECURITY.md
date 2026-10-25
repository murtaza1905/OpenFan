# Security Policy

## Supported versions

Only the latest release on the [Releases](https://github.com/murtaza1905/OpenFan/releases/latest) page receives fixes. Please update before reporting a problem.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Email **muratonurcu@outlook.com** with:

- a description of the issue and its impact,
- steps to reproduce or a proof of concept,
- the OpenFan version and macOS version you tested on.

You will receive an acknowledgement within 7 days. Once the issue is confirmed, a fix is prepared and published as a new release, and the report is credited in `CHANGELOG.md` unless you prefer to stay anonymous.

## Security model

- Reading temperatures and fan speeds happens in the app process through IOKit and needs no privileges.
- Writing fan targets requires root. OpenFan ships `openfan-helper`, a launchd daemon registered with `SMAppService` from inside the app bundle and reached over XPC. macOS asks the user to approve it under Login Items & Extensions.
- The helper only ever writes fan keys: it validates the fan index, clamps the target to the fan's hardware range, switches the fan to manual mode and writes the target. It returns every fan to automatic control when the client disconnects.
- Known limitation: the helper accepts any local XPC client that can reach its Mach service. The worst case is a fan speed change within the hardware range. A code-signing requirement on the connection (`NSXPCConnection.setCodeSigningRequirement`) is planned for builds signed with a Developer ID.
- There is no network code. Releases are built by GitHub Actions from the tagged commit; the workflow is in `.github/workflows/release.yml` and every build log is public.

## Verifying downloads

Every release ships a `SHA256SUMS.txt` file. To verify a download:

```bash
cd ~/Downloads
shasum -a 256 -c SHA256SUMS.txt --ignore-missing
```
