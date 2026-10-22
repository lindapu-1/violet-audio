#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
app=".build/Violet.app"
mkdir -p "$app/Contents/MacOS"
cp ".build/$configuration/Violet" "$app/Contents/MacOS/Violet"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.violet.audio</string>
<key>CFBundleName</key><string>紫麦</string>
<key>CFBundleExecutable</key><string>Violet</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSMicrophoneUsageDescription</key><string>持续在本地保留最近的音频，仅在你选择片段并点击转写时发送给所配置的服务。</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "$PWD/$app"
