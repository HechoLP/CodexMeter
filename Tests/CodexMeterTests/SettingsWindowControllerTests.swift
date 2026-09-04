import AppKit
import XCTest
@testable import CodexMeter

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    private func makeEnvironment() -> SettingsEnvironment {
        SettingsEnvironment(
            limitStore: AccountLimitStore(provider: SettingsTestLimitProvider(), pollingInterval: nil)
        )
    }

    func testSettingsWindowKeepsOneContentControllerAcrossPresentations() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        controller.configure(environment: makeEnvironment())

        controller.present()
        let first = controller.settingsContentViewControllerForTesting
        controller.present()
        XCTAssertTrue(first === controller.settingsContentViewControllerForTesting)
    }

    func testSettingsWindowTitleHasNoProviderSuffix() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        controller.configure(environment: makeEnvironment())

        controller.present()
        let window = controller.settingsContentViewControllerForTesting?.view.window
        window?.layoutIfNeeded()
        let title = window?.title ?? ""
        // The provider-scoped "— Claude Code" suffix is gone; the title is either the
        // default or the selected pane name, never a per-provider window.
        XCTAssertFalse(title.contains("—"))
        XCTAssertFalse(title.contains("Claude Code"))
        XCTAssertTrue(title == "CodexMeter Settings" || title == "General", title)
    }

    func testSettingsWindowBecomesVisibleAndCanReopen() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        defer { controller.closeSettingsForTesting() }
        controller.configure(environment: makeEnvironment())

        controller.present()
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(controller.settingsWindowIsResizableForTesting)
        XCTAssertEqual(
            controller.settingsWindowMinimumContentSizeForTesting,
            NSSize(width: 840, height: 560)
        )
        XCTAssertGreaterThanOrEqual(controller.settingsWindowContentSizeForTesting?.width ?? 0, 840)
        XCTAssertGreaterThanOrEqual(controller.settingsWindowContentSizeForTesting?.height ?? 0, 560)
        let firstContentController = controller.settingsContentViewControllerForTesting

        controller.closeSettingsForTesting()
        XCTAssertFalse(controller.isSettingsWindowVisible)

        controller.present()
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(firstContentController === controller.settingsContentViewControllerForTesting)
    }
}

private struct SettingsTestLimitProvider: AccountLimitProviding {
    func readLimits() async throws -> AccountLimitsSnapshot {
        throw AccountLimitError.trustedAppServerNotFound
    }
}
