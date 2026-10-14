#!/bin/bash
set -uo pipefail

echo "==> Quitting OpenFan"
osascript -e 'quit app "OpenFan"' >/dev/null 2>&1 || true
pkill -x OpenFan >/dev/null 2>&1 || true
sleep 1

echo "==> Removing privileged helper (asks for your password)"
sudo launchctl bootout system/com.openfan.helper >/dev/null 2>&1 || true
sudo pkill -x openfan-helper >/dev/null 2>&1 || true

echo "==> Removing application"
rm -rf /Applications/OpenFan.app
rm -rf ~/Applications/OpenFan.app

echo "==> Removing saved settings and presets"
defaults delete com.openfan.app >/dev/null 2>&1 || true
rm -rf ~/Library/Caches/com.openfan.app
rm -rf ~/Library/Saved\ Application\ State/com.openfan.app.savedState
rm -rf ~/Library/HTTPStorages/com.openfan.app

echo "==> Removing build output"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$SCRIPT_DIR/build" "$SCRIPT_DIR/OpenFan.xcodeproj"

cat <<'EOF'

OpenFan has been removed.
If "OpenFan" still appears under System Settings → General → Login Items & Extensions,
macOS clears that stale entry on its own within a short time; toggling it off and on is harmless.
To reinstall from scratch: ./scripts/install.sh
EOF
