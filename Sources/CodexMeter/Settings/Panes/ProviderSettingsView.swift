import AppKit
import SwiftUI

struct ProviderSettingsView: View {
    let provider: UsageProvider
    @EnvironmentObject private var env: SettingsEnvironment

    var body: some View {
        ProviderSettingsContent(
            provider: provider,
            store: env.usageStore(for: provider),
            limitStore: env.limitStore,
            claude: env.claude
        )
        // Reset @State (confirmsClear) when switching provider panes.
        .id(provider)
    }
}

private struct ProviderSettingsContent: View {
    let provider: UsageProvider
    @ObservedObject var store: UsageStore
    @ObservedObject var limitStore: AccountLimitStore
    @ObservedObject var claude: ClaudeIntegrationStore

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

    @State private var confirmsClear = false

    private var isCodex: Bool { provider == .codex }
    private var isBusy: Bool { store.isMaintainingData || store.isRefreshing || store.isImportingHistory }

    var body: some View {
        SettingsForm {
            headerCard
            accountSection
            if isCodex { limitsSection }
            analyticsSection
            if isCodex { accountTotalsSection } else { claudeNoteSection }
            breakdownSection
            localDataSection
            sourcesSection
            manageDataSection
            privacySection
            footerNotes
        }
        .task { if !isCodex, claude.isEnabled { await claude.refresh() } }
        .confirmationDialog(
            "Clear \(provider.title) local history?",
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button("Clear Local History", role: .destructive) {
                Task { await store.clearLocalHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes only the local \(provider.title) statistics. Session files are not deleted, and records at or before this time will remain excluded.")
        }
    }

    // MARK: Header

    @ViewBuilder private var headerCard: some View {
        if isCodex {
            SettingsProviderCard(provider: .codex, statusLine: "Available", isOn: true) {
                EmptyView()
            }
        } else {
            SettingsProviderCard(provider: .claude, statusLine: claude.statusMessage, isOn: claude.isEnabled) {
                HStack(spacing: 10) {
                    if claude.isEnabled, claude.isConnected {
                        Button {
                            Task { await claude.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .disabled(claude.isRefreshing)
                        .accessibilityLabel("Refresh Claude")
                    }
                    Toggle("", isOn: Binding(
                        get: { claude.isEnabled },
                        set: { enabled in Task { await claude.setEnabled(enabled) } }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("Enable Claude Code")
                }
            }
        }
    }

    // MARK: Account

    @ViewBuilder private var accountSection: some View {
        if isCodex {
            SettingsSection(title: "Account") {
                SettingsInfoRow(text: "Uses the account already signed in to the Codex app", systemImage: "person.crop.circle")
            }
            SettingsNote("Codex remains the primary service. Save, add, or switch accounts from the menu bar popover.")
        } else if claude.isEnabled {
            if claude.isConnected, let account = claude.account {
                SettingsSection(title: "Account") {
                    SettingsValueRow(title: "Account", value: account.displayName)
                    if let plan = account.planName {
                        SettingsValueRow(title: "Plan", value: plan)
                    }
                    SettingsValueRow(title: "Limits", value: claude.statusMessage)
                    SettingsButtonRow(title: "Disconnect", role: .destructive) {
                        Task { await claude.disconnect() }
                    }
                }
            } else {
                SettingsSection(title: "Account") {
                    SettingsValueRow(title: "Status", value: claude.statusMessage)
                    if let detected = claude.detectedAccount {
                        SettingsValueRow(title: "Detected account", value: detected.displayName)
                    }
                    SettingsButtonRow(title: "Add Account", isEnabled: !claude.isRefreshing) {
                        Task { await claude.addCurrentAccount() }
                    }
                }
                if claude.detectedAccount == nil {
                    SettingsNote("Sign in with the `claude` command in your terminal, then choose Add Account.")
                }
                if claude.isRefreshing {
                    SettingsInfoRow(text: "Checking Claude…", systemImage: "hourglass", tint: .secondary)
                }
            }
        }
    }

    // MARK: Limits (Codex)

    private var limitsSection: some View {
        SettingsSection(title: "Limits") {
            SettingsToggleRow("Show account limits", isOn: Binding(
                get: { accountLimitsEnabled },
                set: { newValue in
                    accountLimitsEnabled = newValue
                    limitStore.synchronizeEnabledPreference()
                }
            ))
            SettingsToggleRow("Show additional limits", isOn: $additionalLimitsEnabled, isEnabled: accountLimitsEnabled)
            SettingsToggleRow("Show reset credits", isOn: $resetCreditsEnabled, isEnabled: accountLimitsEnabled)
        }
    }

    // MARK: Analytics

    @ViewBuilder private var analyticsSection: some View {
        SettingsSection(title: "Usage Analytics") {
            SettingsToggleRow("Show usage analytics", isOn: $analyticsEnabled)
            if provider.supportsCostEstimates {
                SettingsToggleRow("Show estimated API-equivalent cost", isOn: $costEstimatesEnabled, isEnabled: analyticsEnabled)
            }
            SettingsToggleRow("Show projects", isOn: $projectsEnabled, isEnabled: analyticsEnabled)
            SettingsToggleRow("Show sessions", isOn: $sessionsEnabled, isEnabled: analyticsEnabled)
            SettingsToggleRow("Show agent details", isOn: $agentDetailsEnabled, isEnabled: analyticsEnabled && sessionsEnabled)
            SettingsToggleRow("Show attachment metadata", isOn: $attachmentMetadataEnabled,
                              isEnabled: analyticsEnabled && sessionsEnabled && isCodex)
        }
        if provider.supportsCostEstimates {
            SettingsNote("Cost is an estimate based on current official API token prices. It is not a bill, subscription charge, or prediction of remaining quota.")
        }
    }

    // MARK: Account totals / Claude note

    private var accountTotalsSection: some View {
        Group {
            SettingsSection(title: "ChatGPT Account Totals") {
                SettingsToggleRow("Use ChatGPT account totals", isOn: $profileSyncEnabled)
            }
            SettingsNote("When enabled, CodexMeter uses your current Codex sign-in only to request aggregate profile totals from chatgpt.com. Credentials and profile responses stay in memory and are never written to CodexMeter's database or logs.")
            SettingsNote("Profile totals use a non-public ChatGPT endpoint and can be delayed to the date shown in the popover.")
            SettingsNote("The main Today value always uses this Mac's live local history. Account totals remain separate and show the server snapshot date.")
        }
    }

    private var claudeNoteSection: some View {
        Group {
            SettingsNote("Token usage comes from Claude Code session logs on this Mac. Five-hour and weekly limits appear after an enabled, connected Claude account completes a response.")
            SettingsNote("Claude cost estimates are not available yet. Unknown prices are never shown as zero cost.")
        }
    }

    // MARK: Breakdown

    private var breakdownSection: some View {
        Group {
            SettingsSection(title: "This Mac Breakdown") {
                SettingsInfoRow(text: "Input is counted", systemImage: "arrow.up")
                SettingsInfoRow(text: "Cached input is included in Input", systemImage: "bolt.horizontal")
                SettingsInfoRow(text: "Output is counted independently", systemImage: "arrow.down")
                SettingsInfoRow(text: "Total equals Input plus Output", systemImage: "sum")
            }
            SettingsNote("Cached input is included in Input, not added to Total a second time. For Claude Code, Input also includes cache creation tokens.")
        }
    }

    // MARK: Local data

    private var localDataSection: some View {
        SettingsSection(title: "\(provider.title) Local Data") {
            SettingsValueRow(title: "Status", value: store.sourceStatusText)
            SettingsValueRow(title: "Source files", value: store.sourceCount.formatted())
            SettingsValueRow(title: "Database size", value: formattedBytes(store.dataStatistics.databaseBytes))
            SettingsValueRow(title: "Oldest record", value: formattedDate(store.dataStatistics.oldestRecord))
            SettingsValueRow(title: "Newest record", value: formattedDate(store.dataStatistics.newestRecord))
            SettingsButtonRow(title: "Open Data Folder") { openDataFolder() }
        }
    }

    // MARK: Sources

    @ViewBuilder private var sourcesSection: some View {
        SettingsSection(title: "Sources") {
            SettingsValueRow(title: "Local \(provider.title) sessions", value: store.sourceStatusText)
            if isCodex {
                SettingsValueRow(title: "Account limits", value: accountLimitStatus)
                SettingsValueRow(title: "Pricing catalog", value: "Available · \(PricingCatalog.current.metadata.version)")
            }
        }
        if !isCodex {
            SettingsNote("Reads ~/.claude/projects, or projects inside CLAUDE_CONFIG_DIR when set in the app's environment.")
        }
    }

    // MARK: Manage data

    private var manageDataSection: some View {
        SettingsSection(title: "Manage Data") {
            if isBusy {
                SettingsRow(title: store.statusMessage) {
                    ProgressView().controlSize(.small)
                }
            } else if let message = store.dataOperationMessage {
                SettingsInfoRow(
                    text: message,
                    systemImage: store.dataOperationFailed ? "exclamationmark.triangle" : "checkmark.circle",
                    tint: store.dataOperationFailed ? .red : .secondary
                )
            }
            SettingsButtonRow(title: "Rebuild Statistics", isEnabled: !isBusy) {
                Task { await store.rebuildStatistics() }
            }
            SettingsButtonRow(title: "Clear Local History", role: .destructive, isEnabled: !isBusy) {
                confirmsClear = true
            }
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        Group {
            SettingsSection(title: "Privacy") {
                SettingsInfoRow(text: "Project identifiers are stored as keyed hashes", systemImage: "lock.shield")
                SettingsInfoRow(text: "Only project folder names are shown", systemImage: "folder.badge.questionmark")
                SettingsInfoRow(text: "Prompts, responses, paths, and attachment contents are not stored", systemImage: "hand.raised")
                if !isCodex {
                    SettingsInfoRow(text: "Claude Code owns the sign-in", systemImage: "key")
                    SettingsInfoRow(text: "CodexMeter never reads or stores Claude credentials", systemImage: "lock.shield")
                }
            }
            SettingsNote(isCodex
                ? "Limits are requested read-only from the signed Codex app-server. The last successful response stays in memory only."
                : "Claude Code logs are read locally. Sign-in stays with Claude Code; CodexMeter changes only the status-line command used to receive documented limit percentages. Disconnecting restores your previous status line.")
        }
    }

    // MARK: Footer

    private var footerNotes: some View {
        Group {
            SettingsNote("Clearing history establishes a new cutoff for \(provider.title) only. Older logs stay excluded on the next refresh. Other services are not affected.")
            if isCodex {
                SettingsNote("Account totals and this Mac's component breakdown are separate data sets and are never added together. Calendar periods use your Mac's current time zone and selected week start.")
            }
        }
    }

    // MARK: Helpers

    private var accountLimitStatus: String {
        switch limitStore.status {
        case .disabled: "Disabled"
        case .loading: "Checking…"
        case .ready: "Connected"
        case .stale: "Last known data"
        case .unavailable: "Unavailable"
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
}
