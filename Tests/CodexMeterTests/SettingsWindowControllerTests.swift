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

        controller.closeSettingsForTesting()
        XCTAssertFalse(controller.isSettingsWindowVisible)

        controller.showSettings(for: store)
        XCTAssertTrue(controller.isSettingsWindowVisible)
    }
}
