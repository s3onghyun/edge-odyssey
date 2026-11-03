#!/bin/sh
# Builds "build/Edge Odyssey.app" for Apple silicon with the Command Line Tools' swiftc
# (no Xcode project needed). Set EDGE_ODYSSEY_BUNDLE_ID for an isolated development copy.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
app="$here/build/Edge Odyssey.app"
bundle_id=${EDGE_ODYSSEY_BUNDLE_ID:-app.edgeodyssey}
version=${EDGE_ODYSSEY_VERSION:-0.2.0}
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/characters" "$app/Contents/Resources/sketches" "$app/Contents/Resources/hooks"
swiftc -swift-version 5 -O -target arm64-apple-macos13 \
  -o "$app/Contents/MacOS/EdgeOdyssey" "$here"/Sources/*.swift
cp -R "$here"/assets/characters/ "$app/Contents/Resources/characters/"
cp "$here"/assets/sketches/*.sprite "$app/Contents/Resources/sketches/"   # discussion drafts
cp "$here"/hooks/* "$app/Contents/Resources/hooks/"
cp "$here"/assets/sounds/*.m4a "$app/Contents/Resources/"   # NSSound(named:) finds them; sources in assets/sounds/src
cp "$here"/assets/icon/AppIcon.icns "$app/Contents/Resources/"   # source: tools/make_icon.py
mkdir -p "$app/Contents/Resources/backgrounds"
cp "$here"/assets/backgrounds/*.jpg "$app/Contents/Resources/backgrounds/"   # focus mode photos: assets/backgrounds/PROVENANCE.md
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>${bundle_id}</string>
  <key>CFBundleName</key><string>Edge Odyssey</string>
  <key>CFBundleExecutable</key><string>EdgeOdyssey</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app" >/dev/null 2>&1 || true
echo "$app"
