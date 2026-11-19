#!/bin/bash
# Builds build/WrapAround.app. Signs with the local identity if present, else ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/WrapAround"
APP=build/WrapAround.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WrapAround"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.klahadore.wraparound</string>
  <key>CFBundleName</key><string>WrapAround</string>
  <key>CFBundleDisplayName</key><string>WrapAround</string>
  <key>CFBundleExecutable</key><string>WrapAround</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict></plist>
PLIST
IDENTITY="${SIGN_IDENTITY:-WrapAround Local Signing}"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --options runtime --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP" && echo "built $APP"
