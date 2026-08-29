import Foundation
import XCTest
@testable import CodexMeter

final class AppPreferencesTests: XCTestCase {
    func testFreshInstallDefaultsToVisibleIconWithoutText() throws {
        let suiteName = "CodexMeterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppPreferences.registerDefaults(in: defaults)

        XCTAssertEqual(defaults.string(forKey: "menuBarDisplay"), MenuBarDisplay.total.rawValue)
        XCTAssertTrue(defaults.bool(forKey: "showMenuBarIcon"))
        XCTAssertFalse(defaults.bool(forKey: "showMenuBarText"))
        XCTAssertFalse(defaults.bool(forKey: "profileSyncEnabled"))
        XCTAssertTrue(
            AppPreferences.shouldShowMenuBarIcon(
                display: defaults.string(forKey: "menuBarDisplay") ?? "",
                showIcon: defaults.bool(forKey: "showMenuBarIcon"),
                showText: defaults.bool(forKey: "showMenuBarText")
            )
        )
        XCTAssertFalse(
            AppPreferences.shouldShowMenuBarText(
                display: defaults.string(forKey: "menuBarDisplay") ?? "",
                showText: defaults.bool(forKey: "showMenuBarText"),
                text: "123M"
            )
        )
    }

    func testLegacyIconOnlyPreferenceMigratesToIndependentVisibilityControls() throws {
        let suiteName = "CodexMeterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("iconOnly", forKey: "menuBarDisplay")
        defaults.set(false, forKey: "showMenuBarIcon")
        defaults.set(true, forKey: "showMenuBarText")

        AppPreferences.registerDefaults(in: defaults)

        XCTAssertEqual(defaults.string(forKey: "menuBarDisplay"), MenuBarDisplay.total.rawValue)
        XCTAssertTrue(defaults.bool(forKey: "showMenuBarIcon"))
        XCTAssertFalse(defaults.bool(forKey: "showMenuBarText"))
        XCTAssertTrue(
            AppPreferences.shouldShowMenuBarText(
                display: defaults.string(forKey: "menuBarDisplay") ?? "",
                showText: true,
                text: "123M"
            )
        )
    }

    func testRegistrationPreservesAnExistingDisplayPreference() throws {
        let suiteName = "CodexMeterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MenuBarDisplay.total.rawValue, forKey: "menuBarDisplay")
        defaults.set(true, forKey: "showMenuBarText")

        AppPreferences.registerDefaults(in: defaults)

        XCTAssertEqual(defaults.string(forKey: "menuBarDisplay"), MenuBarDisplay.total.rawValue)
        XCTAssertTrue(defaults.bool(forKey: "showMenuBarText"))
    }

    func testPreparingDataDirectoryEnforcesOwnerOnlyPermissions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: root.path
        )

        try AppPaths.prepareOwnerOnlyDirectory(at: root)

        let attributes = try FileManager.default.attributesOfItem(atPath: root.path)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        XCTAssertEqual(permissions.intValue & 0o777, 0o700)
    }

    func testRefreshModesExposePredictablePollingChoices() {
        XCTAssertEqual(RefreshMode.thirtySeconds.pollingInterval, 30)
        XCTAssertEqual(RefreshMode.oneMinute.pollingInterval, 60)
        XCTAssertEqual(RefreshMode.twoMinutes.pollingInterval, 120)
        XCTAssertEqual(RefreshMode.fiveMinutes.pollingInterval, 300)
        XCTAssertEqual(RefreshMode.fifteenMinutes.pollingInterval, 900)
        XCTAssertEqual(RefreshMode.thirtyMinutes.pollingInterval, 1_800)
        XCTAssertNil(RefreshMode.manual.pollingInterval)
        XCTAssertTrue(RefreshMode.automatic.usesFileEvents)
    }

    func testDevelopmentBundlesCannotMigrateProductionUsageDatabase() {
        let base = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)

        XCTAssertEqual(
            AppPaths.applicationSupportDirectory(
                baseDirectory: base,
                bundleIdentifier: "dev.codexmeter.CodexMeter"
            ).lastPathComponent,
            "CodexMeter"
        )
        XCTAssertEqual(
            AppPaths.applicationSupportDirectory(
                baseDirectory: base,
                bundleIdentifier: "dev.codexmeter.CodexMeterPreview"
            ).lastPathComponent,
            "CodexMeter-Development"
        )
        XCTAssertEqual(
            AppPaths.applicationSupportDirectory(
                baseDirectory: base,
                bundleIdentifier: nil
            ).lastPathComponent,
            "CodexMeter-Development"
        )
    }
}
