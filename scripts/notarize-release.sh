#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool keychain profile}"
if [[ "$SIGNING_IDENTITY" != 'Developer ID Application:'* ]]; then
  echo 'Public distribution requires a Developer ID Application identity.' >&2
  exit 1
fi
./scripts/package-dmg.sh
codesign --force --timestamp --sign "$SIGNING_IDENTITY" dist/Violet-macOS.dmg
xcrun notarytool submit dist/Violet-macOS.dmg --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > dist/notarization.json
status=$(plutil -extract status raw -o - dist/notarization.json)
if [[ "$status" != 'Accepted' ]]; then
  echo 'Notarization was not accepted; inspect dist/notarization.json.' >&2
  exit 1
fi
xcrun stapler staple dist/Violet-macOS.dmg
xcrun stapler validate dist/Violet-macOS.dmg
shasum -a 256 dist/Violet-macOS.dmg > dist/SHA256SUMS
