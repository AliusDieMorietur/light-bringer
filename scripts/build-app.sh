#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Light Bringer"
EXECUTABLE_NAME="LightBringer"
BUNDLE_ID="com.local.lightbringer"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"
echo "Building release executable…"
swift build -c release --product "$EXECUTABLE_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signing is sufficient for installing the app on this Mac.
codesign --force --sign - "$APP_DIR"

echo "Built: $APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    echo "Installing in /Applications…"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" /Applications/
    echo "Installed: /Applications/$APP_NAME.app"
    echo "Open it from Applications or run: open '/Applications/$APP_NAME.app'"
fi
