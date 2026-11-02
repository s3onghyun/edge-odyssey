#!/bin/sh
# Builds "build/Edge Odyssey.app" with the Command Line Tools' swiftc (no Xcode project needed).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
app="$here/build/Edge Odyssey.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/characters" "$app/Contents/Resources/sketches"
swiftc -swift-version 5 -O -target arm64-apple-macos13 \
  -o "$app/Contents/MacOS/EdgeOdyssey" "$here"/Sources/*.swift
cp -R "$here"/assets/characters/ "$app/Contents/Resources/characters/"
cp "$here"/assets/sketches/*.sprite "$app/Contents/Resources/sketches/"   # discussion drafts
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.edgeodyssey.app</string>
  <key>CFBundleName</key><string>Edge Odyssey</string>
  <key>CFBundleExecutable</key><string>EdgeOdyssey</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app" >/dev/null 2>&1 || true
echo "$app"
