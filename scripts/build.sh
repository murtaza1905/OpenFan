#!/bin/bash
# Builds OpenFan as a universal (arm64 + x86_64) Release app.
#
# Output: build/OpenFan.app (ad-hoc signed)
# To install and launch the result, run ./scripts/install.sh instead.
#
# Requirements: Xcode. XcodeGen is downloaded into build/tools/ when it is not
# installed (no Homebrew needed).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Checking Xcode"
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode not found. Install Xcode from the App Store, open it once, then run:" >&2
    echo "    sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "xcodebuild is not usable. Open Xcode once to accept the license, or run: sudo xcodebuild -license accept" >&2
    exit 1
fi
xcodebuild -version | head -1

echo "==> Checking XcodeGen"
LOCAL_XCODEGEN="build/tools/xcodegen/bin/xcodegen"
if [ -x "$LOCAL_XCODEGEN" ]; then
    export PATH="$PWD/build/tools/xcodegen/bin:$PATH"
fi
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Downloading XcodeGen into build/tools (no Homebrew needed)"
    mkdir -p build/tools
    curl -fsSL --retry 3 -o build/tools/xcodegen.zip \
        https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
    unzip -o -q build/tools/xcodegen.zip -d build/tools
    rm -f build/tools/xcodegen.zip
    xattr -dr com.apple.quarantine build/tools/xcodegen 2>/dev/null || true
    export PATH="$PWD/build/tools/xcodegen/bin:$PATH"
fi
command -v xcodegen >/dev/null 2>&1 || { echo "XcodeGen is still unavailable." >&2; exit 1; }

echo "==> Generating Xcode project"
xcodegen generate --quiet

echo "==> Building OpenFan (Release, universal)"
xcodebuild \
    -project OpenFan.xcodeproj \
    -scheme OpenFan \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    -quiet \
    build

BUILT="build/DerivedData/Build/Products/Release/OpenFan.app"
if [ ! -d "$BUILT" ]; then
    echo "Build failed. Open OpenFan.xcodeproj in Xcode to see the full error list." >&2
    exit 1
fi

rm -rf build/OpenFan.app
ditto "$BUILT" build/OpenFan.app

echo
echo "Built: build/OpenFan.app"
echo "Architectures: $(lipo -archs build/OpenFan.app/Contents/MacOS/OpenFan) / helper: $(lipo -archs build/OpenFan.app/Contents/MacOS/openfan-helper)"
