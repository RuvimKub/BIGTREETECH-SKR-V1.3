#!/bin/bash
# Builds "F3D Quick Look.app" (with thumbnail + preview extensions) without Xcode projects.
# Needs only Xcode Command Line Tools (swiftc, codesign). Run on a Mac:
#   ./build.sh [path/to/any-file.f3d]
# Passing a sample .f3d lets the script detect the file type (UTI) that your Mac
# already assigns to .f3d (e.g. when Fusion 360 is installed).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="F3D Quick Look"
BUNDLE_ID="local.f3dquicklook"
OUT="build"
APP="$OUT/$APP_NAME.app"
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macos13.0"

# --- File types the extensions will handle ---------------------------------
OWN_UTI="$BUNDLE_ID.f3d"
UTIS=("$OWN_UTI")
if [ "${1:-}" != "" ] && [ -f "$1" ]; then
    DETECTED="$(mdls -raw -name kMDItemContentType "$1" 2>/dev/null || true)"
    if [ -n "$DETECTED" ] && [ "$DETECTED" != "(null)" ] && [[ ! "$DETECTED" =~ ^dyn\. ]] && [ "$DETECTED" != "$OWN_UTI" ]; then
        echo "Detected existing type for .f3d: $DETECTED"
        UTIS+=("$DETECTED")
    fi
fi
UTI_XML=""
for u in "${UTIS[@]}"; do UTI_XML+="<string>$u</string>"; done

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/PlugIns"

# --- Host app ---------------------------------------------------------------
swiftc -O -target "$TARGET" -o "$APP/Contents/MacOS/F3DQuickLook" App/main.swift

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>F3DQuickLook</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>UTExportedTypeDeclarations</key>
  <array><dict>
    <key>UTTypeIdentifier</key><string>$OWN_UTI</string>
    <key>UTTypeDescription</key><string>Fusion 360 Design</string>
    <key>UTTypeConformsTo</key><array><string>public.data</string><string>public.archive</string></array>
    <key>UTTypeTagSpecification</key>
    <dict><key>public.filename-extension</key><array><string>f3d</string></array></dict>
  </dict></array>
</dict></plist>
EOF

# --- Extensions -------------------------------------------------------------
build_ext() { # name, extension-point, source dir, principal class, module extra frameworks
    local name="$1" point="$2" src="$3" cls="$4"; shift 4
    local ext="$APP/Contents/PlugIns/$name.appex"
    mkdir -p "$ext/Contents/MacOS"
    swiftc -O -target "$TARGET" -application-extension -parse-as-library \
        -module-name "$name" \
        -Xlinker -e -Xlinker _NSExtensionMain \
        -framework Cocoa "$@" \
        -o "$ext/Contents/MacOS/$name" \
        Shared/F3DPreviewImage.swift "$src"/*.swift
    cat > "$ext/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID.$name</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key><string>$point</string>
    <key>NSExtensionPrincipalClass</key><string>$cls</string>
    <key>NSExtensionAttributes</key>
    <dict>
      <key>QLSupportedContentTypes</key><array>$UTI_XML</array>
      <key>QLThumbnailMinimumDimension</key><integer>0</integer>
      <key>QLSupportsSearchableItems</key><false/>
    </dict>
  </dict>
</dict></plist>
EOF
    cat > "$OUT/$name.entitlements" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.files.user-selected.read-only</key><true/>
</dict></plist>
EOF
    codesign --force --sign - --entitlements "$OUT/$name.entitlements" "$ext"
}

build_ext F3DThumbnail com.apple.quicklook.thumbnail Thumbnail ThumbnailProvider \
    -framework QuickLookThumbnailing
build_ext F3DPreview com.apple.quicklook.preview Preview PreviewProvider \
    -framework QuickLook -framework QuickLookUI -framework UniformTypeIdentifiers

codesign --force --sign - "$APP"

# --- Install ----------------------------------------------------------------
DEST="$HOME/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/$APP_NAME.app"
cp -R "$APP" "$DEST/"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREG" -f "$DEST/$APP_NAME.app" || true
pluginkit -a "$DEST/$APP_NAME.app/Contents/PlugIns/F3DThumbnail.appex" || true
pluginkit -a "$DEST/$APP_NAME.app/Contents/PlugIns/F3DPreview.appex" || true
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

echo
echo "Installed to $DEST/$APP_NAME.app"
echo "Next: open it once, then enable both extensions in"
echo "System Settings > General > Login Items & Extensions > Quick Look,"
echo "then run: killall Finder"
open "$DEST/$APP_NAME.app"
