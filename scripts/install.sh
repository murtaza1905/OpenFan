#!/bin/bash
# Builds OpenFan (scripts/build.sh), replaces the copy in /Applications and
# launches it. Run the same command again to update.
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/build.sh

APP="build/OpenFan.app"
TARGET="/Applications/OpenFan.app"

echo "==> Installing to $TARGET"
if [ -d "$TARGET" ]; then
    osascript -e 'quit app "OpenFan"' >/dev/null 2>&1 || true
    sleep 1
    # Stop a running helper so the new binary is picked up on the next start.
    for label in com.muratonurcu.OpenFan.helper com.openfan.helper; do
        sudo launchctl bootout "system/$label" >/dev/null 2>&1 || true
    done
    rm -rf "$TARGET"
fi
ditto "$APP" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true

echo "==> Launching"
open "$TARGET"

cat <<'EOF'

OpenFan is running: a window opens and an item appears in the menu bar.
To change fan speeds, install the privileged helper once:
  1. Settings tab → "Install helper"
  2. System Settings → General → Login Items & Extensions → allow OpenFan
  3. Back in OpenFan → "Refresh" → status should read "Installed and running"
EOF
