import AppKit
import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("debugLogging") private var debugLogging = false

    var body: some View {
        SettingsForm {
            SettingsSection(title: "Diagnostics") {
                SettingsToggleRow("Enable debug logging", isOn: $debugLogging)
                SettingsButtonRow(title: "Open Log Folder", systemImage: "folder") { openLogFolder() }
            }

            SettingsSection(title: "Codex Account Limit Source") {
                SettingsValueRow(title: "Mode", value: "Automatic")
                SettingsValueRow(title: "Provider", value: "Signed Codex app-server")
            }
            SettingsNote("CodexMeter uses a read-only local RPC request and does not expose reset or purchase actions.")

            SettingsNote("Diagnostics never include prompts, responses, source code, terminal output, or authentication tokens.")
        }
    }

    private func openLogFolder() {
        do {
            try FileManager.default.createDirectory(
                at: AppPaths.logDirectory,
                withIntermediateDirectories: true
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: AppPaths.logDirectory.path
            )
            NSWorkspace.shared.open(AppPaths.logDirectory)
        } catch {
            NSSound.beep()
        }
    }
}
