import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section("Categories") {
                    ForEach(SettingsCategory.allCases) { category in
                        SettingsCategoryRow(category: category)
                            .tag(category)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("CodexMeter")
            .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 300)
            .accessibilityLabel("Settings categories")
            .accessibilityHint("Use the arrow keys to choose a category, then press Tab to change its settings.")
        } detail: {
            if let selectedCategory {
                SettingsDetail(category: selectedCategory) {
                    settingsView(for: selectedCategory)
                }
            } else {
                ContentUnavailableView(
                    "Choose a Category",
                    systemImage: "sidebar.left",
                    description: Text("Select a category from the sidebar to view its settings.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 840, idealWidth: 980, maxWidth: .infinity, minHeight: 560, idealHeight: 680, maxHeight: .infinity)
    }

    @ViewBuilder
    private func settingsView(for category: SettingsCategory) -> some View {
        switch category {
        case .general:
            GeneralSettingsView()
        case .services:
            ServiceSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .usage:
            UsageSettingsView()
        case .data:
            DataSettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case general
    case services
    case appearance
    case usage
    case data
    case advanced
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .services: "Services"
        case .appearance: "Menu Bar"
        case .usage: "Usage & Privacy"
        case .data: "Local Data"
        case .advanced: "Diagnostics"
        case .about: "Information"
        }
    }

    var summary: String {
        switch self {
        case .general: "Startup, refresh, updates, and calendar"
        case .services: "Enable providers and connect accounts"
        case .appearance: "Icon, token text, and popover display"
        case .usage: "What is counted and what stays local"
        case .data: "Source status and history management"
        case .advanced: "Optional logging and log files"
        case .about: "Version, updates, and project links"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .services: "person.crop.circle.badge.checkmark"
        case .appearance: "menubar.rectangle"
        case .usage: "chart.bar.xaxis"
        case .data: "externaldrive"
        case .advanced: "stethoscope"
        case .about: "info.circle"
        }
    }
}

private struct ServiceSettingsView: View {
    @EnvironmentObject private var claude: ClaudeIntegrationStore

    var body: some View {
        Form {
            Section("Codex") {
                LabeledContent("Status", value: "Available")
                Text("Codex remains the primary service and uses the account already signed in to the Codex app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Claude Code") {
                Toggle("Enable Claude Code", isOn: Binding(
                    get: { claude.isEnabled },
                    set: { enabled in Task { await claude.setEnabled(enabled) } }
                ))
                .accessibilityHint("Claude appears in the menu only after an account is added.")

                if claude.isEnabled {
                    if claude.isConnected, let account = claude.account {
                        LabeledContent("Account") {
                            Text(account.displayName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(account.displayName)
                        }
                        if let plan = account.planName {
                            LabeledContent("Plan", value: plan)
                        }
                        LabeledContent("Limits") {
                            Text(claude.statusMessage)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                        HStack {
                            Button("Refresh") { Task { await claude.refresh() } }
                                .disabled(claude.isRefreshing)
                            Button("Disconnect", role: .destructive) {
                                Task { await claude.disconnect() }
                            }
                        }
                    } else {
                        LabeledContent("Status") {
                            Text(claude.statusMessage)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                        if let account = claude.detectedAccount {
                            LabeledContent("Detected account") {
                                Text(account.displayName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(account.displayName)
                            }
                        } else {
                            Text("Sign in with the `claude` command in your terminal, then add the account here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Add Account") {
                            Task { await claude.addCurrentAccount() }
                        }
                        .disabled(claude.isRefreshing)
                        if claude.isRefreshing {
                            ProgressView("Checking Claude…")
                                .controlSize(.small)
                        }
                    }
                }
            }

            Section("Privacy") {
                Label("Claude Code owns the sign-in", systemImage: "key")
                Label("CodexMeter never reads or stores Claude credentials", systemImage: "lock.shield")
                Label("Only 5-hour and weekly percentages and reset times are saved", systemImage: "gauge.with.dots.needle.50percent")
                Text("Disconnecting removes CodexMeter's status-line integration. It does not sign you out of Claude Code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { if claude.isEnabled { await claude.refresh() } }
    }
}

private struct SettingsCategoryRow: View {
    let category: SettingsCategory

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .fontWeight(.medium)
                Text(category.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: category.systemImage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.title) settings. \(category.summary)")
        .accessibilityHint("Select to view this category.")
    }
}

private struct SettingsDetail<Content: View>: View {
    let category: SettingsCategory
    @ViewBuilder let content: Content

    init(category: SettingsCategory, @ViewBuilder content: () -> Content) {
        self.category = category
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityLabel("\(category.title) settings")
                        .accessibilityAddTraits(.isHeader)
                    Text(category.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("refreshMode") private var refreshMode = "automatic"
    @AppStorage("weekStart") private var weekStart = WeekStart.monday.rawValue
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @State private var automaticallyChecksForUpdates = true

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
                Text("Automatic reacts to local session changes and uses a lightweight one-minute fallback check. Fixed intervals are available when you prefer predictable polling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Updates") {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { automaticallyChecksForUpdates },
                        set: { newValue in
                            automaticallyChecksForUpdates = newValue
                            UpdateService.shared.setAutomaticallyChecksForUpdates(newValue)
                        }
                    )
                )
                .disabled(!UpdateService.shared.isAvailable)
                Text("Checks the signed update feed once per day. Token usage data is never sent.")
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
        .onAppear {
            launchAtLogin.refresh()
            UpdateService.shared.start()
            automaticallyChecksForUpdates = UpdateService.shared.automaticallyChecksForUpdates
        }
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
            Section("Menu Bar") {
                Toggle("Show icon", isOn: iconVisibility)
                    .disabled(!showMenuBarText)
                Toggle("Show token text", isOn: textVisibility)
            }
            Section("Token Text") {
                Picker("Content", selection: $display) {
                    ForEach(MenuBarDisplay.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                Picker("Period", selection: $period) {
                    Text("Today").tag(UsagePeriod.today.rawValue)
                    Text("This Week").tag(UsagePeriod.week.rawValue)
                    Text("This Month").tag(UsagePeriod.month.rawValue)
                }
                Picker("Number format", selection: $numberStyle) {
                    Text("Compact").tag(TokenNumberStyle.compact.rawValue)
                    Text("Detailed").tag(TokenNumberStyle.detailed.rawValue)
                }
            }
            .disabled(!showMenuBarText)
            Section("Popover") {
                Toggle("Show cached input", isOn: $showCachedInput)
                Toggle("Show last updated", isOn: $showLastUpdated)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var iconVisibility: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon },
            set: { newValue in
                showMenuBarIcon = newValue
                if !newValue && !showMenuBarText {
                    showMenuBarText = true
                }
            }
        )
    }

    private var textVisibility: Binding<Bool> {
        Binding(
            get: { showMenuBarText },
            set: { newValue in
                showMenuBarText = newValue
                if !newValue && !showMenuBarIcon {
                    showMenuBarIcon = true
                }
            }
        )
    }
}

private struct UsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var limitStore: AccountLimitStore
    @EnvironmentObject private var claude: ClaudeIntegrationStore
    @AppStorage("profileSyncEnabled") private var profileSyncEnabled = AppPreferences.defaultProfileSyncEnabled
    @AppStorage("accountLimitsEnabled") private var accountLimitsEnabled = AppPreferences.defaultAccountLimitsEnabled
    @AppStorage("analyticsEnabled") private var analyticsEnabled = AppPreferences.defaultAnalyticsEnabled
    @AppStorage("costEstimatesEnabled") private var costEstimatesEnabled = AppPreferences.defaultCostEstimatesEnabled
    @AppStorage("additionalLimitsEnabled") private var additionalLimitsEnabled = AppPreferences.defaultAdditionalLimitsEnabled
    @AppStorage("resetCreditsEnabled") private var resetCreditsEnabled = AppPreferences.defaultResetCreditsEnabled
    @AppStorage("projectsEnabled") private var projectsEnabled = AppPreferences.defaultProjectsEnabled
    @AppStorage("sessionsEnabled") private var sessionsEnabled = AppPreferences.defaultSessionsEnabled
    @AppStorage("agentDetailsEnabled") private var agentDetailsEnabled = AppPreferences.defaultAgentDetailsEnabled
    @AppStorage("attachmentMetadataEnabled") private var attachmentMetadataEnabled = AppPreferences.defaultAttachmentMetadataEnabled

    var body: some View {
        Form {
            if store.provider == .codex {
                Section("Codex Limits") {
                    Toggle("Show account limits", isOn: $accountLimitsEnabled)
                        .onChange(of: accountLimitsEnabled) { _, _ in
                            limitStore.synchronizeEnabledPreference()
                        }
                    Toggle("Show additional limits", isOn: $additionalLimitsEnabled)
                        .disabled(!accountLimitsEnabled)
                    Toggle("Show reset credits", isOn: $resetCreditsEnabled)
                        .disabled(!accountLimitsEnabled)
                }
            }
            Section("Usage Analytics") {
                Toggle("Show usage analytics", isOn: $analyticsEnabled)
                if store.provider.supportsCostEstimates {
                    Toggle("Show estimated API-equivalent cost", isOn: $costEstimatesEnabled)
                        .disabled(!analyticsEnabled)
                }
                Toggle("Show projects", isOn: $projectsEnabled)
                    .disabled(!analyticsEnabled)
                Toggle("Show sessions", isOn: $sessionsEnabled)
                    .disabled(!analyticsEnabled)
                Toggle("Show agent details", isOn: $agentDetailsEnabled)
                    .disabled(!analyticsEnabled || !sessionsEnabled)
                Toggle("Show attachment metadata", isOn: $attachmentMetadataEnabled)
                    .disabled(!analyticsEnabled || !sessionsEnabled || store.provider == .claude)
                if store.provider.supportsCostEstimates {
                    Text("Cost is an estimate based on current official API token prices. It is not a bill, subscription charge, or prediction of remaining quota.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if store.provider == .codex {
                Section("ChatGPT Account Totals") {
                    Toggle("Use ChatGPT account totals", isOn: $profileSyncEnabled)
                    Text("When enabled, CodexMeter uses your current Codex sign-in only to request aggregate profile totals from chatgpt.com. Credentials and profile responses stay in memory and are never written to CodexMeter's database or logs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Profile totals use a non-public ChatGPT endpoint and can be delayed to the date shown in the popover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("The main Today value always uses this Mac's live local history. Account totals remain separate and show the server snapshot date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Claude Code") {
                    Text("Token usage comes from Claude Code session logs on this Mac. Five-hour and weekly limits appear after an enabled, connected Claude account completes a response.")
                    Text("Claude cost estimates are not available yet. Unknown prices are never shown as zero cost.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("This Mac Breakdown") {
                Label("Input is counted", systemImage: "arrow.up")
                Label("Cached input is included in Input", systemImage: "bolt.horizontal")
                Label("Output is counted independently", systemImage: "arrow.down")
                Label("Total equals Input plus Output", systemImage: "sum")
                Text("Cached input is included in Input, not added to Total a second time. For Claude Code, Input also includes cache creation tokens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("Project identifiers are stored as keyed hashes", systemImage: "lock.shield")
                Label("Only project folder names are shown", systemImage: "folder.badge.questionmark")
                Label("Prompts, responses, paths, and attachment contents are not stored", systemImage: "hand.raised")
                Text(store.provider == .codex
                     ? "Limits are requested read-only from the signed Codex app-server. The last successful response stays in memory only."
                     : "Claude Code logs are read locally. Sign-in stays with Claude Code; CodexMeter changes only the status-line command used to receive documented limit percentages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Account totals and this Mac's component breakdown are separate data sets and are never added together. Calendar periods use your Mac's current time zone and selected week start.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct DataSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var limitStore: AccountLimitStore
    @State private var confirmsClear = false

    var body: some View {
        Form {
            Section("\(store.provider.title) Local Data") {
                statisticRow("Status", store.sourceStatusText)
                statisticRow("Source files", store.sourceCount.formatted())
                statisticRow("Database size", formattedBytes(store.dataStatistics.databaseBytes))
                statisticRow("Oldest record", formattedDate(store.dataStatistics.oldestRecord))
                statisticRow("Newest record", formattedDate(store.dataStatistics.newestRecord))
                Button("Open Data Folder") {
                    openDataFolder()
                }
            }
            Section("Sources") {
                statisticRow("Local \(store.provider.title) sessions", store.sourceStatusText)
                if store.provider == .codex {
                    statisticRow("Account limits", accountLimitStatus)
                    statisticRow("Pricing catalog", "Available · \(PricingCatalog.current.metadata.version)")
                } else {
                    Text("Reads ~/.claude/projects, or projects inside CLAUDE_CONFIG_DIR when set in the app's environment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            Text("Clearing history establishes a new cutoff for \(store.provider.title) only. Older logs stay excluded on the next refresh. Other services are not affected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog(
            "Clear \(store.provider.title) local history?",
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button("Clear Local History", role: .destructive) {
                Task { await store.clearLocalHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes only the local \(store.provider.title) statistics. Session files are not deleted, and records at or before this time will remain excluded.")
        }
    }

    private func openDataFolder() {
        do {
            let directory = try AppPaths.prepareApplicationSupportDirectory()
            NSWorkspace.shared.open(directory)
        } catch {
            NSSound.beep()
        }
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

    private var accountLimitStatus: String {
        switch limitStore.status {
        case .disabled: "Disabled"
        case .loading: "Checking…"
        case .ready: "Connected"
        case .stale: "Last known data"
        case .unavailable: "Unavailable"
        }
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
            Section("Codex Account Limit Source") {
                LabeledContent("Mode", value: "Automatic")
                LabeledContent("Provider", value: "Signed Codex app-server")
                Text("CodexMeter uses a read-only local RPC request and does not expose reset or purchase actions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "diamond")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CodexMeter")
                        .font(.title3.weight(.semibold))
                    Text("Local Codex token usage in the menu bar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 12)
            .accessibilityElement(children: .combine)

            Form {
                Section("Application") {
                    LabeledContent("Version", value: version)
                    if let build {
                        LabeledContent("Build", value: build)
                    }
                    LabeledContent("Data scope", value: "Local history + optional account totals")
                    LabeledContent("Privacy", value: "Remote totals are memory-only")
                }
                Section("Updates") {
                    Button("Check for Updates…") {
                        UpdateService.shared.checkForUpdates()
                    }
                    .disabled(!UpdateService.shared.isAvailable)
                    Text("Update checks use the signed CodexMeter update feed. Token usage data is never sent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Project") {
                    Link(destination: URL(string: "https://github.com/HechoLP/CodexMeter")!) {
                        Label("Open Source on GitHub", systemImage: "arrow.up.right.square")
                    }
                    Link(destination: URL(string: "https://github.com/HechoLP/CodexMeter/releases")!) {
                        Label("View Releases", systemImage: "shippingbox")
                    }
                    Link(destination: URL(string: "https://github.com/HechoLP/CodexMeter/blob/main/LICENSE")!) {
                        Label("Read MIT License", systemImage: "doc.text")
                    }
                }
                Section {
                    Text("CodexMeter is an independent utility and is not affiliated with or endorsed by OpenAI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
