import ClaudeBridgeCore
import Foundation
import XCTest
@testable import CodexMeter

final class ClaudeRateLimitCodecTests: XCTestCase {
    func testParsesOnlyDocumentedFiveHourAndSevenDayFields() throws {
        let data = Data(#"{"rate_limits":{"five_hour":{"used_percentage":42.5,"resets_at":1800000000},"seven_day":{"used_percentage":75,"resets_at":1800100000}},"session_id":"private","transcript_path":"/private/path"}"#.utf8)
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = try XCTUnwrap(try ClaudeRateLimitCodec.parseStatusLineInput(data, fetchedAt: fetchedAt))

        XCTAssertEqual(snapshot.fiveHour?.usedPercentage, 42.5)
        XCTAssertEqual(snapshot.sevenDay?.usedPercentage, 75)
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        let encoded = try ClaudeRateLimitCodec.encode(snapshot)
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(text.contains("private"))
        XCTAssertFalse(text.contains("transcript"))
    }

    func testRejectsOversizedAndInvalidPercentages() throws {
        XCTAssertThrowsError(
            try ClaudeRateLimitCodec.parseStatusLineInput(
                Data(repeating: 0x20, count: ClaudeRateLimitCodec.maximumInputBytes + 1)
            )
        )
        let invalid = Data(#"{"rate_limits":{"five_hour":{"used_percentage":101},"seven_day":{"used_percentage":-1}}}"#.utf8)
        XCTAssertNil(try ClaudeRateLimitCodec.parseStatusLineInput(invalid))
    }

    func testBridgeOutputIsLimitedToCodexMeterApplicationSupport() {
        let support = URL(fileURLWithPath: "/Users/example/Library/Application Support", isDirectory: true)
        let production = support.appendingPathComponent("CodexMeter/Claude/ClaudeLimits.json")
        let development = support.appendingPathComponent("CodexMeter-Development/Claude/ClaudeLimits.json")

        XCTAssertTrue(ClaudeBridgeOutputPath.isAllowed(production, applicationSupportDirectory: support))
        XCTAssertTrue(ClaudeBridgeOutputPath.isAllowed(development, applicationSupportDirectory: support))
        XCTAssertFalse(ClaudeBridgeOutputPath.isAllowed(URL(fileURLWithPath: "/tmp/ClaudeLimits.json"), applicationSupportDirectory: support))
        XCTAssertFalse(ClaudeBridgeOutputPath.isAllowed(support.appendingPathComponent("CodexMeter/Other.json"), applicationSupportDirectory: support))
    }
}

@MainActor
final class ClaudeIntegrationStoreTests: XCTestCase {
    func testAccountMustBeExplicitlyAddedBeforeClaudeBecomesAvailable() async throws {
        let fixture = try ClaudeIntegrationFixture()
        defer { fixture.cleanup() }
        fixture.defaults.set(true, forKey: "claudeEnabled")
        let account = ClaudeAccount(email: "person@example.com", subscriptionType: "pro", authenticationMethod: "claude.ai")
        let authenticator = StaticClaudeAuthenticator(account: account)
        let installer = RecordingClaudeInstaller()
        let store = ClaudeIntegrationStore(
            authenticator: authenticator,
            installer: installer,
            defaults: fixture.defaults,
            limitsURL: fixture.limitsURL,
            automaticallyRefresh: false
        )

        await store.refresh()
        XCTAssertEqual(store.detectedAccount, account)
        XCTAssertFalse(store.isConnected)
        XCTAssertFalse(store.isAvailable)
        XCTAssertEqual(installer.installCount, 0)

        await store.addCurrentAccount()
        XCTAssertTrue(store.isConnected)
        XCTAssertTrue(store.isAvailable)
        XCTAssertEqual(installer.installCount, 1)
    }

    func testConnectedAccountLoadsWeeklyThenFiveHourLimitsAndDisablesCleanly() async throws {
        let fixture = try ClaudeIntegrationFixture()
        defer { fixture.cleanup() }
        fixture.defaults.set(true, forKey: "claudeEnabled")
        try FileManager.default.createDirectory(at: fixture.limitsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let limits = ClaudeRateLimitSnapshot(
            fiveHour: ClaudeRateLimitWindow(usedPercentage: 20, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: ClaudeRateLimitWindow(usedPercentage: 30, resetsAt: Date(timeIntervalSince1970: 1_800_100_000)),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try ClaudeRateLimitCodec.encode(limits).write(to: fixture.limitsURL)
        let installer = RecordingClaudeInstaller()
        let account = ClaudeAccount(email: "person@example.com", subscriptionType: "max", authenticationMethod: "claude.ai")
        fixture.defaults.set(true, forKey: "claudeAccountLinked")
        fixture.defaults.set(account.linkIdentifier, forKey: "claudeLinkedAccountID")
        let store = ClaudeIntegrationStore(
            authenticator: StaticClaudeAuthenticator(account: account),
            installer: installer,
            defaults: fixture.defaults,
            limitsURL: fixture.limitsURL,
            automaticallyRefresh: false
        )

        await store.refresh()
        XCTAssertEqual(store.snapshot?.windows.map(\.windowDurationMinutes), [10_080, 300])
        XCTAssertEqual(store.snapshot?.windows.map(\.remainingPercent), [70, 80])
        await store.setEnabled(false)
        XCTAssertFalse(store.isAvailable)
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(installer.uninstallCount, 1)
        XCTAssertEqual(fixture.defaults.string(forKey: "usageProvider"), UsageProvider.codex.rawValue)
    }

    func testChangedClaudeAccountMustBeAddedBeforeOldLimitsCanAppear() async throws {
        let fixture = try ClaudeIntegrationFixture()
        defer { fixture.cleanup() }
        fixture.defaults.set(true, forKey: "claudeEnabled")
        fixture.defaults.set(true, forKey: "claudeAccountLinked")
        fixture.defaults.set("different-account", forKey: "claudeLinkedAccountID")
        let current = ClaudeAccount(
            email: "new@example.com",
            subscriptionType: "pro",
            authenticationMethod: "claude.ai"
        )
        let store = ClaudeIntegrationStore(
            authenticator: StaticClaudeAuthenticator(account: current),
            installer: RecordingClaudeInstaller(),
            defaults: fixture.defaults,
            limitsURL: fixture.limitsURL,
            automaticallyRefresh: false
        )

        await store.refresh()

        XCTAssertFalse(store.isAvailable)
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.status, .needsAccount)
        XCTAssertEqual(store.statusMessage, "Add this Claude account to CodexMeter")
    }
}

final class ClaudeStatusLineInstallerTests: XCTestCase {
    func testInstallPreservesAndUninstallRestoresExistingStatusLine() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = root.appendingPathComponent(".claude/settings.json")
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let helper = root.appendingPathComponent("CodexMeterClaudeBridge")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"theme":"dark","statusLine":{"type":"command","command":"existing-status"}}"#.utf8)
            .write(to: settings)
        FileManager.default.createFile(atPath: helper.path, contents: Data("helper".utf8), attributes: [.posixPermissions: 0o700])
        let installer = ClaudeStatusLineInstaller(
            settingsURL: settings,
            managedDirectory: managed,
            bridgeSource: { helper }
        )

        try installer.install()
        let installed = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        )
        XCTAssertEqual(installed["theme"] as? String, "dark")
        let command = try XCTUnwrap((installed["statusLine"] as? [String: Any])?["command"] as? String)
        XCTAssertTrue(command.contains("CodexMeterClaudeBridge"))
        XCTAssertTrue(command.contains("ClaudeLimits.json"))

        try installer.uninstall()
        let restored = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        )
        XCTAssertEqual((restored["statusLine"] as? [String: Any])?["command"] as? String, "existing-status")
        XCTAssertEqual(restored["theme"] as? String, "dark")
    }
}

private struct StaticClaudeAuthenticator: ClaudeAuthenticating {
    let account: ClaudeAccount?
    func accountStatus() async throws -> ClaudeAccount? { account }
    func beginLogin() async throws {}
}

private final class RecordingClaudeInstaller: ClaudeStatusLineInstalling, @unchecked Sendable {
    private(set) var installCount = 0
    private(set) var uninstallCount = 0
    func install() throws { installCount += 1 }
    func uninstall() throws { uninstallCount += 1 }
}

private struct ClaudeIntegrationFixture {
    let root: URL
    let suiteName: String
    let defaults: UserDefaults
    let limitsURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        suiteName = "CodexMeter.ClaudeTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        limitsURL = root.appendingPathComponent("ClaudeLimits.json")
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
