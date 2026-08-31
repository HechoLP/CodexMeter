import AppKit
import XCTest
@testable import CodexMeter

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testSettingsRebindsItsDataStoreWhenProviderChanges() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        let limits = AccountLimitStore(provider: SettingsTestLimitProvider(), pollingInterval: nil)
        controller.showSettings(for: UsageStore(automaticallyRefresh: false), limitStore: limits)
        let codexController = controller.settingsContentViewControllerForTesting
        controller.showSettings(for: UsageStore(provider: .claude, automaticallyRefresh: false), limitStore: limits)
        XCTAssertFalse(codexController === controller.settingsContentViewControllerForTesting)
        XCTAssertEqual(controller.settingsContentViewControllerForTesting?.view.window?.title,
                       "CodexMeter Settings — Claude Code")
    }

    func testSettingsWindowBecomesVisibleAndCanReopen() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        let store = UsageStore()
        let limitStore = AccountLimitStore(
            provider: SettingsTestLimitProvider(),
            pollingInterval: nil
        )
        defer { controller.closeSettingsForTesting() }

        controller.showSettings(for: store, limitStore: limitStore)
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(controller.settingsWindowIsResizableForTesting)
        XCTAssertEqual(
            controller.settingsWindowMinimumContentSizeForTesting,
            NSSize(width: 840, height: 560)
        )
        XCTAssertGreaterThanOrEqual(
            controller.settingsWindowContentSizeForTesting?.width ?? 0,
            840
        )
        XCTAssertGreaterThanOrEqual(
            controller.settingsWindowContentSizeForTesting?.height ?? 0,
            560
        )
        let firstContentController = controller.settingsContentViewControllerForTesting

        controller.closeSettingsForTesting()
        XCTAssertFalse(controller.isSettingsWindowVisible)

        controller.showSettings(for: store, limitStore: limitStore)
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(firstContentController === controller.settingsContentViewControllerForTesting)
    }
}

private struct SettingsTestLimitProvider: AccountLimitProviding {
    func readLimits() async throws -> AccountLimitsSnapshot {
        throw AccountLimitError.trustedAppServerNotFound
    }
}
