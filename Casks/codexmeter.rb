cask "codexmeter" do
  version "0.1.0"
  sha256 "38a1ec06849647555fb73e2a401371a94f76be551c2d4cb2352ea3da9d745e2f"

  url "https://github.com/HechoLP/CodexMeter/releases/download/v#{version}/CodexMeter-#{version}.zip",
      verified: "github.com/HechoLP/CodexMeter/"
  name "CodexMeter"
  desc "Local Codex token usage in the menu bar"
  homepage "https://github.com/HechoLP/CodexMeter"

  depends_on macos: :sonoma

  app "CodexMeter.app"

  zap trash: [
    "~/Library/Application Support/CodexMeter",
    "~/Library/Preferences/dev.codexmeter.CodexMeter.plist",
  ]
end
