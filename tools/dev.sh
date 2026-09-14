#!/bin/zsh
# Builds a Debug macdock.app, signs it, and relaunches it.
#
# The signing matters more than it looks. macOS keys an Accessibility grant
# to the app's designated requirement. A plain ad hoc signature's requirement
# is a hash of the binary, so every rebuild is a new app to macOS and the
# grant silently stops applying. Signing ad hoc with the bundle identifier as
# the requirement instead gives an identity that survives rebuilds, with no
# certificate, Apple ID or trust settings involved. A certificate in the
# keychain is used when one is present or named; its default requirement is
# stable too.
#
#   tools/dev.sh                             ad hoc with a stable requirement, or the first identity
#   MACDOCK_SIGN_IDENTITY="macdock dev" tools/dev.sh
set -euo pipefail

cd "$(dirname "$0")/.."

found="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)"
identity="${MACDOCK_SIGN_IDENTITY:-${found:--}}"
app="build/DerivedData/Build/Products/Debug/macdock.app"

xcodegen generate -q
xcodebuild build \
    -project macdock.xcodeproj \
    -scheme macdock \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData \
    -quiet \
    CODE_SIGNING_ALLOWED=NO

if [[ "$identity" == "-" ]]; then
    codesign --force --sign - --requirements '=designated => identifier "app.macdock"' "$app"
    echo "signed ad hoc, requirement: identifier app.macdock (grants survive rebuilds)"
else
    codesign --force --deep --sign "$identity" "$app"
    echo "signed as: $identity"
fi

pkill -x macdock || true
sleep 0.5
open -a "$app"
