import SwiftUI

/// Holds the stores every settings pane needs so the window is a single view,
/// not one rebuilt per selected provider. Plain reference holder — the panes
/// observe the nested stores directly with `@ObservedObject`.
@MainActor
final class SettingsEnvironment: ObservableObject {
    let codexStore: UsageStore
    let claudeStore: UsageStore
    let limitStore: AccountLimitStore
    let claude: ClaudeIntegrationStore
    let codexAccounts: CodexAccountStore

    init(
        codexStore: UsageStore = UsageStore(automaticallyRefresh: false),
        claudeStore: UsageStore = UsageStore(provider: .claude, automaticallyRefresh: false),
        limitStore: AccountLimitStore = AccountLimitStore(pollingInterval: nil),
        claude: ClaudeIntegrationStore = ClaudeIntegrationStore(automaticallyRefresh: false),
        // Defaults to an empty in-memory vault, never the real Keychain: this
        // default is what layout tests construct, and a test must never read or
        // prompt for the developer's actual saved Codex logins. The app wires
        // the real `CodexAccountStore.shared` explicitly in CodexMeterApp.
        codexAccounts: CodexAccountStore = CodexAccountStore(vault: EphemeralAccountVault())
    ) {
        self.codexStore = codexStore
        self.claudeStore = claudeStore
        self.limitStore = limitStore
        self.claude = claude
        self.codexAccounts = codexAccounts
    }

    func usageStore(for provider: UsageProvider) -> UsageStore {
        provider == .claude ? claudeStore : codexStore
    }
}

private struct EphemeralAccountVault: AccountVault {
    func load() throws -> [SavedCodexAccount] { [] }
    func save(_ accounts: [SavedCodexAccount]) throws {}
}
