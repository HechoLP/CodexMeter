cask "codexmeter" do
  version "0.1.0"
  sha256 "7a49e20f0ee4e3859e3333fdf0c1d213da3258d7462dabc840bff29746c1207d"

  url "https://github.com/HechoLP/codex-meter/releases/download/v#{version}/CodexMeter-#{version}.zip",
      verified: "github.com/HechoLP/codex-meter/"
  name "CodexMeter"
  desc "Local Codex token usage in the menu bar"
  homepage "https://github.com/HechoLP/codex-meter"

  depends_on macos: :sonoma

  app "CodexMeter.app"

  zap trash: [
    "~/Library/Application Support/CodexMeter",
    "~/Library/Preferences/dev.codexmeter.CodexMeter.plist",
  ]
end
