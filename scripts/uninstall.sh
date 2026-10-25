#!/bin/bash
# Quits OpenFan, removes the privileged helper, the app, its settings and presets.
set -uo pipefail

echo "==> Quitting OpenFan"
osascript -e 'quit app "OpenFan"' >/dev/null 2>&1 || true
pkill -x OpenFan >/dev/null 2>&1 || true
sleep 1

echo "==> Removing privileged helper (asks for your password)"
for label in com.muratonurcu.OpenFan.helper com.openfan.helper; do
    sudo launchctl bootout "system/$label" >/dev/null 2>&1 || true
done
sudo pkill -x openfan-helper >/dev/null 2>&1 || true

echo "==> Removing application"
rm -rf /Applications/OpenFan.app
rm -rf ~/Applications/OpenFan.app

echo "==> Removing saved settings and presets"
for domain in com.muratonurcu.OpenFan com.openfan.app; do
    defaults delete "$domain" >/dev/null 2>&1 || true
    rm -rf ~/Library/Caches/"$domain"
    rm -rf ~/Library/Saved\ Application\ State/"$domain".savedState
    rm -rf ~/Library/HTTPStorages/"$domain"
done

echo "==> Removing build output"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$SCRIPT_DIR/build" "$SCRIPT_DIR/dist" "$SCRIPT_DIR/OpenFan.xcodeproj"

cat <<'EOF'

OpenFan has been removed. Fans are back under system control.
If "OpenFan" still appears under System Settings → General → Login Items & Extensions,
macOS clears that stale entry on its own within a short time; toggling it off and on is harmless.
To reinstall from scratch: ./scripts/install.sh
EOF
