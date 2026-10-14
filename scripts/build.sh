#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode command line tools not found. Install Xcode from the App Store, open it once, then run:" >&2
    echo "    sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

if [ -x "build/tools/xcodegen/bin/xcodegen" ]; then
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

xcodegen generate

xcodebuild \
    -project OpenFan.xcodeproj \
    -scheme OpenFan \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    build

mkdir -p build
rm -rf build/OpenFan.app
cp -R build/DerivedData/Build/Products/Release/OpenFan.app build/OpenFan.app

echo
echo "Built: build/OpenFan.app"
echo "Run ./scripts/install.sh to copy it to /Applications and launch it, or ./scripts/make-dmg.sh for a disk image."
