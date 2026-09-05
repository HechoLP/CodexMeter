import SwiftUI

struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    private var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    var body: some View {
        SettingsForm {
            SettingsInfoRow(text: "CodexMeter — local Codex and Claude Code token usage in the menu bar", systemImage: "diamond")

            SettingsSection(title: "Application") {
                SettingsValueRow(title: "Version", value: version)
                if let build {
                    SettingsValueRow(title: "Build", value: build)
                }
                SettingsValueRow(title: "Data scope", value: "Local history + optional account totals")
                SettingsValueRow(title: "Privacy", value: "Remote totals are memory-only")
            }

            SettingsSection(title: "Updates") {
                SettingsButtonRow(title: "Check for Updates…", systemImage: "arrow.triangle.2.circlepath",
                                  isEnabled: UpdateService.shared.isAvailable) {
                    UpdateService.shared.checkForUpdates()
                }
            }
            SettingsNote("Update checks use the signed CodexMeter update feed. Token usage data is never sent.")

            SettingsSection(title: "Project") {
                SettingsLinkRow(title: "Open Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                                destination: URL(string: "https://github.com/HechoLP/CodexMeter")!)
                SettingsLinkRow(title: "View Releases", systemImage: "shippingbox",
                                destination: URL(string: "https://github.com/HechoLP/CodexMeter/releases")!)
                SettingsLinkRow(title: "Read MIT License", systemImage: "doc.text",
                                destination: URL(string: "https://github.com/HechoLP/CodexMeter/blob/main/LICENSE")!)
            }

            SettingsNote("CodexMeter is an independent utility and is not affiliated with or endorsed by OpenAI or Anthropic.")
        }
    }
}
