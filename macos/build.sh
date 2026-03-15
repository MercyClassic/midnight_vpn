#!/bin/bash
set -e

CERT="MidnightDev"
PACKAGE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cert) CERT="$2"; shift ;;
        --package) PACKAGE=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

swift build -c release

rm -rf Midnight.app
mkdir -p Midnight.app/Contents/MacOS
mkdir -p Midnight.app/Contents/Resources

cp .build/release/Midnight Midnight.app/Contents/MacOS/
cp Assets/gear.png Midnight.app/Contents/Resources/

mkdir -p Midnight.iconset
sips -z 16 16     Assets/gear.png --out Midnight.iconset/icon_16x16.png
sips -z 32 32     Assets/gear.png --out Midnight.iconset/icon_16x16@2x.png
sips -z 32 32     Assets/gear.png --out Midnight.iconset/icon_32x32.png
sips -z 64 64     Assets/gear.png --out Midnight.iconset/icon_32x32@2x.png
sips -z 128 128   Assets/gear.png --out Midnight.iconset/icon_128x128.png
sips -z 256 256   Assets/gear.png --out Midnight.iconset/icon_128x128@2x.png
sips -z 256 256   Assets/gear.png --out Midnight.iconset/icon_256x256.png
iconutil -c icns Midnight.iconset -o Midnight.app/Contents/Resources/Midnight.icns
rm -rf Midnight.iconset

cat > Midnight.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Midnight</string>
    <key>CFBundleIdentifier</key>
    <string>com.personal.midnight</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>Midnight</string>
    <key>CFBundleIconFile</key>
    <string>Midnight</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

xattr -cr Midnight.app
codesign --force --deep --sign "$CERT" Midnight.app
echo "✅ Certified: $CERT"

if [ "$PACKAGE" = true ]; then
    rm -rf dmg_tmp
    mkdir -p dmg_tmp
    cp -r Midnight.app dmg_tmp/
    ln -s /Applications dmg_tmp/Applications

    hdiutil create \
        -volname "Midnight" \
        -srcfolder dmg_tmp \
        -ov \
        -format UDZO \
        Midnight.dmg

    rm -rf dmg_tmp
    echo "✅ Midnight.dmg compiled"
fi
