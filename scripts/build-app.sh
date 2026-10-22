#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
app=".build/Violet.app"
mkdir -p "$app/Contents/MacOS"
if [[ "$configuration" == "release" ]]; then
  binaries=()
  for architecture in arm64 x86_64; do
    triple="$architecture-apple-macosx14.0"
    swift build -c release --triple "$triple"
    binary_dir=$(swift build -c release --triple "$triple" --show-bin-path)
    binaries+=("$binary_dir/Violet")
  done
  lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/Violet"
else
  swift build -c "$configuration"
  binary_dir=$(swift build -c "$configuration" --show-bin-path)
  cp "$binary_dir/Violet" "$app/Contents/MacOS/Violet"
fi
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
identity="${SIGNING_IDENTITY:--}"
if [[ "$identity" == "-" ]]; then
  codesign --force --sign - "$app"
else
  codesign --force --sign "$identity" --options runtime --timestamp --entitlements Resources/Violet.entitlements "$app"
fi
codesign --verify --deep --strict "$app"
echo "$PWD/$app"
