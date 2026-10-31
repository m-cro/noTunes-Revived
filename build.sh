#!/bin/zsh
# Builds noTunesRevived.app and optionally installs a login item (./build.sh install)
set -e
cd "$(dirname "$0")"
APP=noTunesRevived.app
rm -rf $APP && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
swiftc -O main.swift -o $APP/Contents/MacOS/noTunesRevived
cp assets/tray-on.png assets/tray-off.png $APP/Contents/Resources/
ICONSET=$(mktemp -d)/AppIcon.iconset && mkdir -p $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s assets/AppIcon.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) assets/AppIcon.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o $APP/Contents/Resources/AppIcon.icns
cat > $APP/Contents/Info.plist <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>noTunesRevived</string>
<key>CFBundleIdentifier</key><string>local.notunesrevived</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>noTunesRevived</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
P
codesign --force --sign - $APP 2>/dev/null || true
if [[ "$1" == install ]]; then
  mkdir -p ~/Applications && rm -rf ~/Applications/$APP && cp -R $APP ~/Applications/
  osascript -e 'tell application "System Events" to make login item at end with properties {path:"'$HOME'/Applications/'$APP'", hidden:true}'
  open ~/Applications/$APP
fi
echo built $APP
