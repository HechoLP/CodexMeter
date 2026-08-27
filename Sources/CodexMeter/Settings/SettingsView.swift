import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            UsageSettingsView()
                .tabItem { Label("Usage", systemImage: "chart.bar") }
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
            AdvancedSettingsView()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 390)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("refreshMode") private var refreshMode = "automatic"
    @AppStorage("weekStart") private var weekStart = WeekStart.monday.rawValue
    @StateObject private var launchAtLogin = LaunchAtLoginService()

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                LabeledContent("Status", value: launchAtLogin.statusText)
                if launchAtLogin.status == .requiresApproval {
                    Button("Open Login Items Settings") {
                        launchAtLogin.openSystemSettings()
                    }
                }
                if let message = launchAtLogin.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section("Refresh") {
                Picker("Refresh", selection: $refreshMode) {
                    ForEach(RefreshMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                Text("Automatic uses file events with a lightweight one-minute fallback check.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Calendar") {
                Picker("Week starts on", selection: $weekStart) {
                    Text("Monday").tag(WeekStart.monday.rawValue)
                    Text("Sunday").tag(WeekStart.sunday.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { launchAtLogin.refresh() }
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage("menuBarDisplay") private var display = AppPreferences.defaultMenuBarDisplay
    @AppStorage("menuBarPeriod") private var period = UsagePeriod.today.rawValue
    @AppStorage("numberStyle") private var numberStyle = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @AppStorage("showMenuBarText") private var showMenuBarText = AppPreferences.defaultShowMenuBarText

    var body: some View {
        Form {
            Picker("Menu bar display", selection: $display) {
                ForEach(MenuBarDisplay.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            Picker("Menu bar period", selection: $period) {
                Text("Today").tag(UsagePeriod.today.rawValue)
                Text("This Week").tag(UsagePeriod.week.rawValue)
                Text("This Month").tag(UsagePeriod.month.rawValue)
            }
            Picker("Number format", selection: $numberStyle) {
                Text("Compact").tag(TokenNumberStyle.compact.rawValue)
                Text("Detailed").tag(TokenNumberStyle.detailed.rawValue)
            }
            Section("Menu bar elements") {
                Toggle("Show icon", isOn: iconVisibility)
                    .disabled(isIconOnly)
                Toggle("Show text", isOn: textVisibility)
                    .disabled(isIconOnly)
                Text(
                    isIconOnly
                        ? "Icon Only always shows the CodexMeter icon without token text."
                        : "CodexMeter keeps at least one menu bar element visible."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Popover") {
                Toggle("Show cached input", isOn: $showCachedInput)
                Toggle("Show last updated", isOn: $showLastUpdated)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { enforceIconOnlyVisibility() }
        .onChange(of: display) { _, _ in enforceIconOnlyVisibility() }
    }

    private var isIconOnly: Bool { display == MenuBarDisplay.iconOnly.rawValue }

    private func enforceIconOnlyVisibility() {
        guard isIconOnly else { return }
        showMenuBarIcon = true
        showMenuBarText = false
    }

    private var iconVisibility: Binding<Bool> {
        Binding(
            get: { isIconOnly ? true : showMenuBarIcon },
            set: { newValue in
                guard !isIconOnly else { return }
                showMenuBarIcon = newValue
                if !newValue && !showMenuBarText {
                    showMenuBarText = true
                }
            }
        )
    }

    private var textVisibility: Binding<Bool> {
        Binding(
            get: { isIconOnly ? false : showMenuBarText },
            set: { newValue in
                guard !isIconOnly else { return }
                showMenuBarText = newValue
                if !newValue && !showMenuBarIcon {
                    showMenuBarIcon = true
                }
            }
        )
    }
}

private struct UsageSettingsView: View {
    var body: some View {
        Form {
            Section("Accounting") {
                Label("Input includes cached input", systemImage: "arrow.up")
                Label("Cached input is reported separately", systemImage: "bolt.horizontal")
                Label("Output is counted independently", systemImage: "arrow.down")
                Label("Total equals input plus output", systemImage: "sum")
            }
            Text("Cached input is a subset of input and is never added to the total a second time. All periods follow your Mac's current calendar and time zone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct DataSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var confirmsClear = false

    var body: some View {
        Form {
            Section("Codex Local Data") {
                statisticRow("Status", store.sourceStatusText)
                statisticRow("Source files", store.sourceCount.formatted())
                statisticRow("Database size", formattedBytes(store.dataStatistics.databaseBytes))
                statisticRow("Oldest record", formattedDate(store.dataStatistics.oldestRecord))
                statisticRow("Newest record", formattedDate(store.dataStatistics.newestRecord))
                Button("Open Data Folder") {
                    openDataFolder()
                }
            }
            Section {
                if store.isMaintainingData || store.isRefreshing || store.isImportingHistory {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(store.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } else if let message = store.dataOperationMessage {
                    Label(
                        message,
                        systemImage: store.dataOperationFailed
                            ? "exclamationmark.triangle"
                            : "checkmark.circle"
                    )
                    .foregroundStyle(store.dataOperationFailed ? .red : .secondary)
                    .accessibilityLabel("Data operation status, \(message)")
                }
                Button("Rebuild Statistics") {
                    Task { await store.rebuildStatistics() }
                }
                .disabled(store.isMaintainingData || store.isRefreshing || store.isImportingHistory)
                Button("Clear Local History", role: .destructive) {
                    confirmsClear = true
                }
                .disabled(store.isMaintainingData || store.isRefreshing || store.isImportingHistory)
            }
            Text("Clearing history establishes a new local cutoff. Older Codex logs stay excluded instead of being imported again on the next refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog(
            "Clear CodexMeter local history?",
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button("Clear Local History", role: .destructive) {
                Task { await store.clearLocalHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes CodexMeter's local statistics. It does not delete Codex session files, and records at or before this time will remain excluded.")
        }
    }

    private func openDataFolder() {
        let directory = AppPaths.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formattedDate(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .shortened) ?? "None"
    }

    private func statisticRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(value)")
    }
}

private struct AdvancedSettingsView: View {
    @AppStorage("debugLogging") private var debugLogging = false

    var body: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Enable debug logging", isOn: $debugLogging)
                Button("Open Log Folder") {
                    openLogFolder()
                }
            }
            Text("Diagnostics never include prompts, responses, source code, terminal output, or authentication tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
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

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    private var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "diamond")
                .font(.system(size: 40, weight: .medium))
                .accessibilityHidden(true)
            Text("CodexMeter")
                .font(.title2.bold())
            Text(build.map { "Version \(version) (\($0))" } ?? "Version \(version)")
                .foregroundStyle(.secondary)
            Text("Unofficial utility. Not affiliated with or endorsed by OpenAI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/HechoLP/codex-meter")!)
                Link("Releases", destination: URL(string: "https://github.com/HechoLP/codex-meter/releases")!)
                Link("MIT License", destination: URL(string: "https://github.com/HechoLP/codex-meter/blob/main/LICENSE")!)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
