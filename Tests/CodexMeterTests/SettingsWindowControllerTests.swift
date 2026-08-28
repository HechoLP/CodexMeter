import AppKit
import XCTest
@testable import CodexMeter

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testSettingsWindowBecomesVisibleAndCanReopen() {
        _ = NSApplication.shared
        let controller = SettingsWindowController()
        let store = UsageStore()
        defer { controller.closeSettingsForTesting() }

        controller.showSettings(for: store)
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

        controller.showSettings(for: store)
        XCTAssertTrue(controller.isSettingsWindowVisible)
        XCTAssertTrue(firstContentController === controller.settingsContentViewControllerForTesting)
    }
}
