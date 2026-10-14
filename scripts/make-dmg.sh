#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(grep -m1 "CFBundleShortVersionString" project.yml | sed -E "s/.*: *\"?([0-9.]+)\"?/\1/")"
VERSION="${VERSION:-1.0.0}"
DMG="build/OpenFan-${VERSION}.dmg"
STAGING="build/dmg-staging"

echo "==> Checking XcodeGen"
if [ -x "build/tools/xcodegen/bin/xcodegen" ]; then
    export PATH="$PWD/build/tools/xcodegen/bin:$PATH"
fi
if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew install xcodegen
    else
        mkdir -p build/tools
        curl -L --fail -o build/tools/xcodegen.zip \
            https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
        unzip -o -q build/tools/xcodegen.zip -d build/tools
        export PATH="$PWD/build/tools/xcodegen/bin:$PATH"
    fi
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building universal (arm64 + x86_64) Release"
xcodebuild \
    -project OpenFan.xcodeproj \
    -scheme OpenFan \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    build | grep -E "error:|BUILD" || true

APP="build/DerivedData/Build/Products/Release/OpenFan.app"
if [ ! -d "$APP" ]; then
    echo "Build failed. Open OpenFan.xcodeproj in Xcode to see the full error list." >&2
    exit 1
fi

echo "==> Architectures:"
lipo -archs "$APP/Contents/MacOS/OpenFan"
lipo -archs "$APP/Contents/MacOS/openfan-helper"

echo "==> Creating DMG"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/OpenFan.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/README.txt" <<'EOF'
OpenFan
=======
1. Drag OpenFan.app to the Applications folder.
2. First launch: right-click OpenFan.app -> Open -> Open (the app is self-signed, Gatekeeper asks once).
   If macOS says the app is "damaged", run in Terminal:
       xattr -dr com.apple.quarantine /Applications/OpenFan.app
3. In OpenFan: Settings -> Install helper -> allow in System Settings -> Login Items -> Refresh.
EOF
hdiutil create -volname "OpenFan ${VERSION}" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo
echo "Created: $DMG"
