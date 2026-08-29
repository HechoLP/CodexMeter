import Foundation
import XCTest
@testable import CodexMeter

@MainActor
final class AccountLimitStoreTests: XCTestCase {
    func testOfflineFailureKeepsLastKnownSnapshotInMemory() async throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: "accountLimitsEnabled")
        let expected = AccountLimitsSnapshot(
            windows: [
                AccountLimitWindow(
                    id: "weekly",
                    limitID: "codex",
                    displayName: "Codex",
                    windowDurationMinutes: 10_080,
                    usedPercent: 25,
                    resetsAt: nil
                )
            ],
            resetCredits: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
        let provider = SequencedLimitProvider([
            .success(expected),
            .failure(AccountLimitError.timedOut)
        ])
        let store = AccountLimitStore(
            provider: provider,
            defaults: defaults,
            pollingInterval: nil
        )

        await store.refresh()
        XCTAssertEqual(store.snapshot, expected)
        XCTAssertEqual(store.status, .ready)

        await store.refresh()
        XCTAssertEqual(store.snapshot, expected)
        XCTAssertEqual(store.status, .stale)
        XCTAssertEqual(store.statusMessage, "Showing last known limits")
    }

    func testDisabledPreferenceNeverCallsProvider() async throws {
        let defaults = try makeDefaults()
        defaults.set(false, forKey: "accountLimitsEnabled")
        let provider = SequencedLimitProvider([])
        let store = AccountLimitStore(
            provider: provider,
            defaults: defaults,
            pollingInterval: nil
        )

        await store.refresh()
        XCTAssertEqual(store.status, .disabled)
        XCTAssertNil(store.snapshot)
        let calls = await provider.callCount
        XCTAssertEqual(calls, 0)
    }

    func testProviderPropagatesTimeoutWithoutLaunchingFallbackSource() async {
        let provider = AppServerLimitProvider(
            executableResolver: { URL(fileURLWithPath: "/trusted/codex") },
            runner: TimeoutRunner()
        )

        do {
            _ = try await provider.readLimits()
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? AccountLimitError, .timedOut)
        }
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "AccountLimitStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private actor SequencedLimitProvider: AccountLimitProviding {
    private var outcomes: [Result<AccountLimitsSnapshot, Error>]
    private(set) var callCount = 0

    init(_ outcomes: [Result<AccountLimitsSnapshot, Error>]) {
        self.outcomes = outcomes
    }

    func readLimits() async throws -> AccountLimitsSnapshot {
        callCount += 1
        guard !outcomes.isEmpty else { throw AccountLimitError.malformedResponse }
        return try outcomes.removeFirst().get()
    }
}

private struct TimeoutRunner: AppServerProcessRunning {
    func run(
        executable _: URL,
        arguments _: [String],
        standardInput _: Data,
        timeout _: Duration,
        maximumOutputBytes _: Int
    ) async throws -> Data {
        throw AccountLimitError.timedOut
    }
}
