#!/bin/sh
# Builds a universal "build/Edge Odyssey.app" with the Command Line Tools' swiftc
# (no Xcode project needed). Set EDGE_ODYSSEY_BUNDLE_ID for an isolated development copy.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
app="$here/build/Edge Odyssey.app"
bundle_id=${EDGE_ODYSSEY_BUNDLE_ID:-app.edgeodyssey}
version=${EDGE_ODYSSEY_VERSION:-0.3.0}

# Compile each architecture separately, then join them with lipo. ARCHS is useful when
# iterating locally, while releases and the default build stay universal.
case ${ARCHS:-universal} in
  universal) architectures="arm64 x86_64" ;;
  arm64|x86_64) architectures=${ARCHS} ;;
  *) echo "ARCHS must be universal, arm64, or x86_64" >&2; exit 2 ;;
esac

scratch=$(mktemp -d "${TMPDIR:-/tmp}/edge-odyssey-build.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

bins=""
for architecture in $architectures; do
  binary="$scratch/EdgeOdyssey-$architecture"
  swiftc -swift-version 5 -O -target "$architecture-apple-macos13" \
    -o "$binary" "$here"/Sources/*.swift
  bins="$bins $binary"
done

set -- $bins
if [ "$#" -eq 1 ]; then
  bin=$1
else
  bin="$scratch/EdgeOdyssey-universal"
  lipo -create "$@" -output "$bin"
fi

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/characters" "$app/Contents/Resources/sketches" "$app/Contents/Resources/hooks"
cp "$bin" "$app/Contents/MacOS/EdgeOdyssey"
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
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ko</string><string>ja</string><string>zh-Hans</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app" >/dev/null 2>&1 || true
echo "$app"
