# A Homebrew cask for macdock, for a tap or for homebrew-cask once the
# project meets its notability bar. Replace OWNER with the GitHub owner and
# refresh the sha256 from the release's .sha256 file on each version.
cask "macdock" do
  version "0.2.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/OWNER/macdock/releases/download/v#{version}/macdock-#{version}.dmg"
  name "macdock"
  desc "A dock on every display"
  homepage "https://github.com/OWNER/macdock"

  depends_on macos: ">= :tahoe"

  app "macdock.app"

  zap trash: [
    "~/Library/Application Support/macdock",
  ]
end
