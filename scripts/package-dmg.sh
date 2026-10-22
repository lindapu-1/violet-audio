#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
stage=$(mktemp -d "${TMPDIR:-/tmp}/violet-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto .build/Violet.app "$stage/Violet.app"
ln -s /Applications "$stage/Applications"
mkdir -p dist
hdiutil create -volname 'Violet 紫麦' -srcfolder "$stage" -ov -format UDZO dist/Violet-macOS.dmg
shasum -a 256 dist/Violet-macOS.dmg > dist/SHA256SUMS
