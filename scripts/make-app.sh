#!/usr/bin/env bash
# Assemble Tree.app from the built binary. A real bundle gives the process the
# application identity the window server needs to deliver global hotkey events
# (and to attach Accessibility grants stably) — a bare `swift run` binary gets
# neither. Codesigning/notarization is layered on top in M7.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
swift build -c "$CONFIG" >/dev/null
BIN="$(swift build -c "$CONFIG" --show-bin-path)/treeclip"

APP="build/Tree.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/treeclip"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>treeclip</string>
  <key>CFBundleIdentifier</key><string>com.samcui.treeclip</string>
  <key>CFBundleName</key><string>Tree</string>
  <key>CFBundleDisplayName</key><string>Tree</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>treeclip — MIT</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so a stable code identity backs the Accessibility grant.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built $APP"
