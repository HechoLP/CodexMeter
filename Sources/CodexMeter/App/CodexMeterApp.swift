import AppKit
import SwiftUI

/*
 THESIS: Codex usage should read like a quiet macOS instrument, not a web dashboard squeezed into the menu bar.
 OWN-WORLD: System materials, semantic labels, hairline separators, tabular numerals, and one diamond meter mark.
 STORY: Launch, see today's total, click once for its composition and nearby periods, then return to work.
 FIRST VIEWPORT: A 320-point popover leads with today's total, follows with input/cached/output rows, then week/month/all-time links and a compact status footer.
 FORM: Native macOS utility, selected from the binding product brief; code-first session with no decorative visual comp.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
*/
@main
struct CodexMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: UsageStore
    @StateObject private var claudeStore: UsageStore
    @AppStorage("usageProvider") private var usageProvider = UsageProvider.codex.rawValue
    @StateObject private var profileStore: ProfileUsageStore
    @StateObject private var accountLimitStore: AccountLimitStore
    @AppStorage("menuBarDisplay") private var menuBarDisplay = AppPreferences.defaultMenuBarDisplay
    @AppStorage("menuBarPeriod") private var menuBarPeriod = UsagePeriod.today.rawValue
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @AppStorage("showMenuBarText") private var showMenuBarText = AppPreferences.defaultShowMenuBarText

    init() {
        AppPreferences.registerDefaults()
        let store = UsageStore()
        let claudeStore = UsageStore(provider: .claude)
        let profileStore = ProfileUsageStore()
        let accountLimitStore = AccountLimitStore()
        _store = StateObject(wrappedValue: store)
        _claudeStore = StateObject(wrappedValue: claudeStore)
        _profileStore = StateObject(wrappedValue: profileStore)
        _accountLimitStore = StateObject(wrappedValue: accountLimitStore)
        CodexAccountStore.shared.onAccountWillChange = { [weak profileStore, weak accountLimitStore] in
            profileStore?.clearForAccountSwitch()
            accountLimitStore?.clearForAccountSwitch()
        }
        CodexAccountStore.shared.onAccountOperationFinished = { [weak profileStore, weak accountLimitStore] in
            Task {
                // An old read-only app-server may still be winding down; its result is
                // discarded by the generation guard before requesting the new account.
                while accountLimitStore?.isRefreshing == true || profileStore?.isRefreshing == true {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                await accountLimitStore?.refresh()
                await profileStore?.refresh(weekStart: Self.selectedWeekStart)
            }
        }
        Task { @MainActor [weak store] in
            await store?.refresh()
        }
        Task { @MainActor [weak claudeStore] in
            await claudeStore?.refresh()
        }
        Task { @MainActor [weak profileStore] in
            profileStore?.synchronizeEnabledPreference()
            await profileStore?.refresh(weekStart: Self.selectedWeekStart)
        }
        Task { @MainActor [weak accountLimitStore] in
            await accountLimitStore?.refresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView(accounts: .shared)
                .id(selectedStore.provider)
                .environmentObject(selectedStore)
                .environmentObject(profileStore)
                .environmentObject(accountLimitStore)
        } label: {
            HStack(spacing: 4) {
                if resolvedShowIcon {
                    Image(systemName: "diamond")
                        .accessibilityHidden(true)
                }
                if resolvedShowText {
                    Text(menuBarText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 220)
                }
            }
                .accessibilityLabel(menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(selectedStore)
                .environmentObject(profileStore)
                .environmentObject(accountLimitStore)
        }
    }

    private var resolvedShowIcon: Bool {
        AppPreferences.shouldShowMenuBarIcon(
            display: menuBarDisplay,
            showIcon: showMenuBarIcon,
            showText: showMenuBarText
        )
    }

    private var resolvedShowText: Bool {
        AppPreferences.shouldShowMenuBarText(
            display: menuBarDisplay,
            showText: showMenuBarText,
            text: menuBarText
        )
    }

    private var menuBarText: String {
        selectedStore.menuBarText(totalOverride: profileTotalOverride)
    }

    private var menuBarAccessibilityLabel: String {
        "\(selectedStore.provider.title), " + selectedStore.menuBarAccessibilityLabel(
            totalOverride: profileTotalOverride,
            totalPeriodDescription: profilePeriodDescription
        )
    }

    private var profileTotalOverride: Int64? {
        guard selectedStore.provider.supportsAccountTotals,
              profileStore.isEnabled, let snapshot = profileStore.snapshot else { return nil }
        return UsageDisplayPolicy.profileOverride(
            for: UsagePeriod(rawValue: menuBarPeriod) ?? .today,
            profileSnapshot: snapshot
        )
    }

    private var profilePeriodDescription: String? {
        guard selectedStore.provider.supportsAccountTotals,
              profileStore.isEnabled, let snapshot = profileStore.snapshot else { return nil }
        let asOf = snapshot.statsAsOf.formatted(.dateTime.month(.abbreviated).day())
        return switch UsagePeriod(rawValue: menuBarPeriod) ?? .today {
        case .today: nil
        case .week: "this week in the ChatGPT profile through \(asOf)"
        case .month: "this month in the ChatGPT profile through \(asOf)"
        case .allTime: "in the ChatGPT profile through \(asOf)"
        }
    }

    private var selectedStore: UsageStore {
        UsageProvider(rawValue: usageProvider) == .claude ? claudeStore : store
    }

    private static var selectedWeekStart: WeekStart {
        let defaults = UserDefaults.standard
        let rawValue = defaults.object(forKey: "weekStart") == nil
            ? WeekStart.monday.rawValue
            : defaults.integer(forKey: "weekStart")
        return WeekStart(rawValue: rawValue) ?? .monday
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        UpdateService.shared.start()
    }
}
