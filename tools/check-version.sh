#!/bin/bash
# Refuses a release whose version is not the same everywhere: the tag being
# released, MARKETING_VERSION in project.yml (what the app reports and the
# DMG is named after), and the newest version section in CHANGELOG.md (what
# the release notes are built from). Without a tag it checks only the last
# two, which CI does on every push, so a forgotten changelog rename shows up
# before anyone tags.
#   tools/check-version.sh v0.4.0
#   tools/check-version.sh
set -euo pipefail
cd "$(dirname "$0")/.."

project="$(sed -n 's/.*MARKETING_VERSION: "\(.*\)".*/\1/p' project.yml)"

# The first "## X.Y.Z" heading; an Unreleased section above it is skipped.
heading="$(grep -m1 -E '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md || true)"
changelog="${heading#\#\# }"
changelog="${changelog%% *}"

# v0.5.0-rc1 releases version 0.5.0 as a pre-release.
tag="${1:-}"
tag="${tag#v}"
tag="${tag%%-*}"

status=0
if [[ "$project" != "$changelog" ]]; then
    echo "check-version: project.yml says $project, the newest CHANGELOG.md section is ${changelog:-missing}" >&2
    status=1
fi
if [[ -n "$tag" && "$tag" != "$project" ]]; then
    echo "check-version: the tag says $tag, project.yml says $project" >&2
    status=1
fi
if [[ $status -eq 0 ]]; then
    echo "check-version: ${1:-project.yml} and CHANGELOG.md agree on $project"
fi
exit $status
