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

    init(
        codexStore: UsageStore = UsageStore(automaticallyRefresh: false),
        claudeStore: UsageStore = UsageStore(provider: .claude, automaticallyRefresh: false),
        limitStore: AccountLimitStore = AccountLimitStore(pollingInterval: nil),
        claude: ClaudeIntegrationStore = ClaudeIntegrationStore(automaticallyRefresh: false)
    ) {
        self.codexStore = codexStore
        self.claudeStore = claudeStore
        self.limitStore = limitStore
        self.claude = claude
    }

    func usageStore(for provider: UsageProvider) -> UsageStore {
        provider == .claude ? claudeStore : codexStore
    }
}
