#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Alt.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CACHE_DIR="$PROJECT_DIR/.cache"

echo "🔨 Building Alt. Native macOS Application..."

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$CACHE_DIR"

# Collect all swift source files
SOURCES=(
    "$PROJECT_DIR/Sources/Main.swift"
    "$PROJECT_DIR/Sources/Common/WindowManager.swift"
    "$PROJECT_DIR/Sources/Common/HistoryManager.swift"
    "$PROJECT_DIR/Sources/Common/HistoryWindowController.swift"
    "$PROJECT_DIR/Sources/Common/DesktopIconManager.swift"
    "$PROJECT_DIR/Sources/Common/HotKeyManager.swift"
    "$PROJECT_DIR/Sources/Settings/SettingsManager.swift"
    "$PROJECT_DIR/Sources/Capture/CaptureManager.swift"
    "$PROJECT_DIR/Sources/Capture/RecordingManager.swift"
    "$PROJECT_DIR/Sources/Capture/RecordingHUDWindowController.swift"
    "$PROJECT_DIR/Sources/Capture/RecordingAreaSelectorController.swift"
    "$PROJECT_DIR/Sources/Capture/ScrollingCaptureManager.swift"
    "$PROJECT_DIR/Sources/QuickAccess/QuickAccessPanel.swift"
    "$PROJECT_DIR/Sources/Editor/AnnotationModels.swift"
    "$PROJECT_DIR/Sources/Editor/EditorCanvasView.swift"
    "$PROJECT_DIR/Sources/Editor/EditorWindowController.swift"
    "$PROJECT_DIR/Sources/Pin/PinWindowController.swift"
    "$PROJECT_DIR/Sources/OCR/OCRManager.swift"
    "$PROJECT_DIR/Sources/Menu/MenuBarManager.swift"
)

# Compile using swiftc
echo "📦 Compiling Swift sources..."
swiftc \
    -O \
    -module-cache-path "$CACHE_DIR" \
    "${SOURCES[@]}" \
    -o "$MACOS_DIR/Alt"

# Copy App Icon
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Alt</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.alt.screen</string>
    <key>CFBundleName</key>
    <string>Alt.</string>
    <key>CFBundleDisplayName</key>
    <string>Alt.</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$MACOS_DIR/Alt"

# Sign application bundle with ad-hoc signature so macOS TCC seals resources & Info.plist
echo "🔏 Signing application bundle..."
codesign --force --deep --sign - "$APP_DIR"

echo "✅ Build Successful!"
echo "📍 Application created at: $APP_DIR"

if [ "$1" == "--release" ]; then
    echo "📦 Packaging DMG and ZIP releases..."
    mkdir -p "$PROJECT_DIR/releases"
    ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$PROJECT_DIR/releases/Alt-macOS.zip"
    DMG_TEMP="$BUILD_DIR/dmg_temp"
    rm -rf "$DMG_TEMP" "$PROJECT_DIR/releases/Alt.dmg"
    mkdir -p "$DMG_TEMP"
    cp -R "$APP_DIR" "$DMG_TEMP/"
    ln -s /Applications "$DMG_TEMP/Applications"
    hdiutil create -volname "Alt" -srcfolder "$DMG_TEMP" -ov -format UDZO "$PROJECT_DIR/releases/Alt.dmg" > /dev/null
    rm -rf "$DMG_TEMP"
    echo "🎉 Release files updated at: $PROJECT_DIR/releases/"
fi
