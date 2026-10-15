#!/bin/bash
set -e

APP_NAME="SkillManager"
BUNDLE_ID="com.andreacurti.skillmanager"
VERSION="1.0.0"

echo "Building $APP_NAME release..."
swift build -c release

BINARY=".build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
  echo "Error: binary not found at $BINARY"
  exit 1
fi

APP_DIR="build/$APP_NAME.app/Contents"
rm -rf "build/$APP_NAME.app"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

cp "$BINARY" "$APP_DIR/MacOS/$APP_NAME"

ICON_SRC="SkillManager/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$APP_DIR/Resources/AppIcon.icns"
  echo "Icon added."
fi

cat > "$APP_DIR/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

echo "Signing app with ad-hoc signature..."
codesign --force --deep --sign - "build/$APP_NAME.app"

echo ""
echo "Done! App bundle created at:"
echo "  build/$APP_NAME.app"
echo ""
echo "To open it:"
echo "  open build/$APP_NAME.app"
echo ""
echo "NOTE: Users who download this app will need to right-click > Open"
echo "the first time, since it is not notarized with Apple."
