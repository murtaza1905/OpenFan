#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Checking Xcode"
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode command line tools not found. Install Xcode from the App Store, open it once, then run:" >&2
    echo "    sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "xcodebuild is not usable. Open Xcode once to accept the license, or run: sudo xcodebuild -license accept" >&2
    exit 1
fi

echo "==> Checking XcodeGen"
LOCAL_XCODEGEN="build/tools/xcodegen/bin/xcodegen"
if [ -x "$LOCAL_XCODEGEN" ]; then
    export PATH="$PWD/build/tools/xcodegen/bin:$PATH"
fi
if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew install xcodegen
    else
        echo "Downloading XcodeGen (no Homebrew found)"
        mkdir -p build/tools
        curl -L --fail -o build/tools/xcodegen.zip \
            https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
        unzip -o -q build/tools/xcodegen.zip -d build/tools
        export PATH="$PWD/build/tools/xcodegen/bin:$PATH"
    fi
fi
command -v xcodegen >/dev/null 2>&1 || { echo "XcodeGen is still unavailable." >&2; exit 1; }

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building OpenFan (Release)"
xcodebuild \
    -project OpenFan.xcodeproj \
    -scheme OpenFan \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    build | grep -E "error:|warning: .*Swift|BUILD" || true

APP="build/DerivedData/Build/Products/Release/OpenFan.app"
if [ ! -d "$APP" ]; then
    echo "Build failed. Open OpenFan.xcodeproj in Xcode to see the full error list." >&2
    exit 1
fi

echo "==> Installing to /Applications"
if [ -d /Applications/OpenFan.app ]; then
    osascript -e 'quit app "OpenFan"' >/dev/null 2>&1 || true
    sleep 1
    sudo launchctl bootout system/com.openfan.helper >/dev/null 2>&1 || true
    rm -rf /Applications/OpenFan.app
fi
cp -R "$APP" /Applications/OpenFan.app
xattr -dr com.apple.quarantine /Applications/OpenFan.app 2>/dev/null || true

echo "==> Launching"
open /Applications/OpenFan.app

cat <<'EOF'

OpenFan is running in the menu bar.
Next steps inside the app:
  1. Menu bar icon → "Open OpenFan…" → Settings tab
  2. "Install helper"
  3. System Settings → General → Login Items & Extensions → allow OpenFan
  4. Back in OpenFan → "Refresh" → status should read "Installed and running"
EOF
