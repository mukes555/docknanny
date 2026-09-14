#!/bin/zsh
# Builds a Debug macdock.app, signs it, and relaunches it.
#
# The signing identity matters more than it looks. macOS ties an
# Accessibility grant to the app's code signature. An ad hoc signature has no
# certificate, so the identity is a hash of the binary itself and every
# rebuild is a new app to macOS: the grant silently stops applying. Signing
# with any certificate, self-signed included, gives a stable identity, and
# the grant survives rebuilds.
#
#   tools/dev.sh                             first identity in the keychain, else ad hoc
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

codesign --force --deep --sign "$identity" "$app"
if [[ "$identity" == "-" ]]; then
    echo "note: signed ad hoc. macOS forgets the Accessibility grant on every rebuild;"
    echo "      create a code-signing certificate (see CONTRIBUTING.md) to keep it."
else
    echo "signed as: $identity"
fi

pkill -x macdock || true
sleep 0.5
open -a "$app"
