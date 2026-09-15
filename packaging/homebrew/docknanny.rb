# A Homebrew cask for DockNanny, for a tap or for homebrew-cask once the
# project meets its notability bar. Replace OWNER with the GitHub owner and
# refresh the sha256 from the release's .sha256 file on each version.
cask "docknanny" do
  version "0.4.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/OWNER/DockNanny/releases/download/v#{version}/DockNanny-#{version}.dmg"
  name "DockNanny"
  desc "A dock on every display"
  homepage "https://github.com/OWNER/DockNanny"

  depends_on macos: ">= :tahoe"

  app "DockNanny.app"

  zap trash: [
    "~/Library/Application Support/DockNanny",
  ]
end
