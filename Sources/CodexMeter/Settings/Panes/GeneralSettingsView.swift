import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("refreshMode") private var refreshMode = "automatic"
    @AppStorage("weekStart") private var weekStart = WeekStart.monday.rawValue
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @State private var automaticallyChecksForUpdates = true

    var body: some View {
        SettingsForm {
            SettingsSection(title: "Startup") {
                SettingsToggleRow(
                    "Launch at Login",
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
                SettingsValueRow(title: "Status", value: launchAtLogin.statusText)
                if launchAtLogin.status == .requiresApproval {
                    SettingsButtonRow(title: "Open Login Items Settings", systemImage: "gearshape") {
                        launchAtLogin.openSystemSettings()
                    }
                }
            }
            if let message = launchAtLogin.errorMessage {
                SettingsNote(message, tint: .red)
            }

            SettingsSection(title: "Refresh") {
                SettingsPickerRow(title: "Mode", selection: $refreshMode) {
                    ForEach(RefreshMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            }
            SettingsNote("Automatic reacts to session changes with a one-minute fallback check.")

            SettingsSection(title: "Updates") {
                SettingsToggleRow(
                    "Automatically check for updates",
                    isEnabled: UpdateService.shared.isAvailable,
                    get: { automaticallyChecksForUpdates },
                    set: { newValue in
                        automaticallyChecksForUpdates = newValue
                        UpdateService.shared.setAutomaticallyChecksForUpdates(newValue)
                    }
                )
            }
            SettingsNote("Checks the signed update feed once per day. Token usage data is never sent.")

            SettingsSection(title: "Calendar") {
                SettingsPickerRow(title: "Week starts on", selection: $weekStart) {
                    Text("Monday").tag(WeekStart.monday.rawValue)
                    Text("Sunday").tag(WeekStart.sunday.rawValue)
                }
            }
        }
        .onAppear {
            launchAtLogin.refresh()
            UpdateService.shared.start()
            automaticallyChecksForUpdates = UpdateService.shared.automaticallyChecksForUpdates
        }
    }
}
