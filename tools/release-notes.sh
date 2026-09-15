#!/bin/bash
# Prints the GitHub release body for a version: the matching CHANGELOG.md
# section under a "What's new" heading, then how to install. The release
# workflow feeds it to the release, so the changelog is the one place release
# notes are written.
#   tools/release-notes.sh 0.4.0
set -euo pipefail

version="${1:?usage: tools/release-notes.sh <version>}"
cd "$(dirname "$0")/.."

# The heading must be exactly this version: "## 0.4" must not match 0.4.0,
# and "## 0.4.0" must not match 0.4.01.
section="$(awk -v ver="$version" '
    BEGIN { gsub(/\./, "\\.", ver) }
    $0 ~ "^## " ver "([^0-9.]|$)" { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' CHANGELOG.md)"
section="$(printf '%s\n' "$section" | sed -e '/./,$!d')"

if [[ -z "$section" ]]; then
    # A release without notes means the newest section was never renamed
    # from Unreleased; failing the release beats publishing it empty.
    echo "release-notes.sh: no '## $version' section in CHANGELOG.md" >&2
    exit 1
fi

cat <<NOTES
## What's new in $version

$section

## Install

\`\`\`bash
brew tap mukes555/tap && brew install --cask docknanny
\`\`\`

Or download **DockNanny-$version.dmg** below, drag the app to Applications,
and strip the quarantine once, since the build is ad hoc signed:

\`\`\`bash
xattr -dr com.apple.quarantine /Applications/DockNanny.app
\`\`\`

Requires macOS 26 (Tahoe) on Apple Silicon. \`SHA256SUMS\` lists the
checksum of the DMG.
NOTES
