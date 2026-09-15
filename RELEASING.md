# Releasing

1. Rename the `Unreleased` section of `CHANGELOG.md` to the version and set
   `MARKETING_VERSION` in `project.yml` to match, commit.
2. Tag: `git tag -a vX.Y.Z -m "DockNanny X.Y.Z"` and push the tag.
3. The release workflow checks that the tag, `MARKETING_VERSION`, and the
   newest `CHANGELOG.md` section agree (`tools/check-version.sh`, which CI
   also runs on every push), builds `DockNanny-X.Y.Z.dmg`, writes
   `SHA256SUMS`, and publishes a GitHub release with both attached. The
   release notes are that changelog section (`tools/release-notes.sh`), so
   keep entries user facing. An `-rc`, `-beta`, or `-alpha` tag is marked
   pre-release and leaves the tap alone.
   If the tag went up in a batch of more than three (GitHub then emits no
   push event) or a release needs rebuilding, run the workflow by hand:
   `gh workflow run release.yml -f tag=vX.Y.Z`.
4. The tap: with a `HOMEBREW_TAP_TOKEN` secret (a fine-grained personal
   access token with contents: write on `mukes555/homebrew-tap`) the
   workflow renders `packaging/homebrew/docknanny.rb.tmpl` with the version
   and checksum and pushes it to the tap as `Casks/docknanny.rb`. Without
   the secret, render it by hand:

   ```bash
   VERSION=X.Y.Z; SHA=$(curl -sL https://github.com/mukes555/docknanny/releases/download/v$VERSION/SHA256SUMS | awk '/dmg$/ {print $1}')
   sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" packaging/homebrew/docknanny.rb.tmpl > ../homebrew-tap/Casks/docknanny.rb
   ```

   and open a pull request on the tap.

Users then run `brew tap mukes555/tap && brew install --cask docknanny`, and
later `brew upgrade --cask docknanny`.

## Signing

Release builds are ad hoc signed with the bundle identifier as their
designated requirement, so an upgrade keeps the Accessibility grant a user
made. A Developer ID would remove the Gatekeeper dialog and the quarantine
step in the cask; set `CODESIGN_IDENTITY` and `NOTARY_PROFILE` for
`tools/release.sh` once one exists.

The identifier requirement is a trade-off, and worth knowing about. macOS
keys the grant to the requirement, so any binary signed ad hoc with the
identifier `app.docknanny` is trusted the same way, without a prompt. That
takes code already running on the Mac, which could ask for the grant itself
and would be little worse off; the alternative, granting again after every
upgrade, is what the requirement exists to avoid. A Developer ID (whose
default requirement is anchored to the certificate) removes the trade-off
along with the dialog.
