#!/bin/zsh
# Builds a Release DockNanny.app, signs it, wraps it in a DMG, and optionally
# notarizes it.
#
#   tools/release.sh                 ad-hoc signed DMG in build/release/
#   CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=DockNanny tools/release.sh
#                                    Developer ID signed, notarized, stapled
#
# NOTARY_PROFILE is a keychain profile made once with
# `xcrun notarytool store-credentials`. Nothing here needs a secret in the
# repository.
set -euo pipefail

cd "$(dirname "$0")/.."

# The app's own version, so the DMG is named after what it contains rather
# than after whatever tag happens to be newest.
version="$(sed -n 's/.*MARKETING_VERSION: "\(.*\)".*/\1/p' project.yml)"
identity="${CODESIGN_IDENTITY:--}"
out="build/release"
staging="$out/staging"
app="$out/DockNanny.app"
dmg="$out/DockNanny-$version.dmg"

rm -rf "$out"
mkdir -p "$staging"

echo "==> Generating project"
xcodegen generate -q

echo "==> Building Release"
xcodebuild build \
    -project DockNanny.xcodeproj \
    -scheme DockNanny \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData \
    -quiet \
    CODE_SIGNING_ALLOWED=NO
cp -R build/DerivedData/Build/Products/Release/DockNanny.app "$app"

echo "==> Signing with: $identity"
if [[ "$identity" == "-" ]]; then
    # Ad hoc, with the bundle identifier as the designated requirement so
    # macOS keeps a user's Accessibility grant across upgrades (a plain ad
    # hoc signature is keyed to the binary's hash and loses it every time).
    codesign --force --sign - --requirements '=designated => identifier "app.docknanny"' "$app"
else
    # Hardened runtime is what notarization checks for.
    codesign --force --deep --options runtime --timestamp --sign "$identity" "$app"
fi
codesign --verify --strict "$app"

echo "==> Building DMG"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "DockNanny" -srcfolder "$staging" -ov -format UDZO "$dmg"
rm -rf "$staging"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Notarizing"
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
fi

(cd "$out" && shasum -a 256 "$(basename "$dmg")" | tee SHA256SUMS)
echo "==> Done: $dmg"
