#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${STILL_UNIVERSAL:-0}" == "1" ]]; then
    # Build separately so universal packaging also works without full Xcode.
    swift build -c release --arch arm64
    ARM_BIN="$(swift build -c release --arch arm64 --show-bin-path)"
    swift build -c release --arch x86_64
    INTEL_BIN="$(swift build -c release --arch x86_64 --show-bin-path)"
    BIN_DIR="$PWD/.build/universal-release"
    mkdir -p "$BIN_DIR"
    lipo -create "$ARM_BIN/Still" "$INTEL_BIN/Still" -output "$BIN_DIR/Still"
else
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi
APP="$PWD/dist/余刻.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Still" "$APP/Contents/MacOS/Still"
ICONSET="$PWD/.build/Still.iconset"
mkdir -p "$ICONSET"
swift scripts/icon.swift "$PWD/.build/icon.png"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" .build/icon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" .build/icon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Still.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Still</string>
<key>CFBundleIdentifier</key><string>com.danny.still</string>
<key>CFBundleName</key><string>余刻</string>
<key>CFBundleDisplayName</key><string>余刻</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.2</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleIconFile</key><string>Still</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
