import CryptoKit
import Foundation
import XCTest
@testable import CodexMeter

final class SQLiteDatabaseTests: XCTestCase {
    func testMigrationReopenDuplicateInsertAndSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("CodexMeter.sqlite")
        let database = try SQLiteDatabase(url: url)
        let checkpoint = SourceCheckpoint(
            sourcePath: "/fixture.jsonl",
            fileIdentity: "1:2",
            generation: 0,
            committedOffset: 100,
            sessionID: "session",
            inheritsHistory: false,
            model: "model",
            projectPath: "/project"
        )
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let event = UsageEvent(
            eventKey: "stable-event",
            occurredAt: date,
            sessionID: "session",
            model: "model",
            projectPath: "/project",
            usage: TokenUsage(inputTokens: 100, cachedInputTokens: 60, outputTokens: 20),
            sourcePath: checkpoint.sourcePath,
            sourcePosition: 10
        )
        let normalization = UsageNormalizationState(
            cumulativeHighWaterMark: event.usage,
            quality: .exact
        )

        try await database.commit(events: [event], checkpoint: checkpoint, normalizationState: normalization)
        try await database.commit(events: [event], checkpoint: checkpoint, normalizationState: normalization)
        let eventCount = try await database.eventCount()
        let savedCheckpoint = try await database.checkpoint(for: checkpoint.sourcePath)
        XCTAssertEqual(eventCount, 1)
        XCTAssertEqual(savedCheckpoint, checkpoint)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let snapshot = try await database.usageSnapshot(
            now: date.addingTimeInterval(60),
            calendar: calendar,
            weekStart: .monday
        )
        XCTAssertEqual(snapshot.allTime, event.usage)
        XCTAssertEqual(snapshot.quality, .exact)

        let reopened = try SQLiteDatabase(url: url)
        let reopenedEventCount = try await reopened.eventCount()
        let reopenedCutoff = try await reopened.importCutoff()
        XCTAssertEqual(reopenedEventCount, 1)
        XCTAssertNil(reopenedCutoff)
    }

    func testTransactionRollsBackInvalidEventAndCheckpoint() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("db.sqlite"))
        let checkpoint = SourceCheckpoint.fresh(sourcePath: "/invalid", fileIdentity: "1:1")
        let invalid = UsageEvent(
            eventKey: "invalid",
            occurredAt: Date(),
            sessionID: nil,
            model: nil,
            projectPath: nil,
            usage: TokenUsage(inputTokens: 1, cachedInputTokens: 2, outputTokens: 0),
            sourcePath: checkpoint.sourcePath,
            sourcePosition: 0
        )

        do {
            try await database.commit(events: [invalid], checkpoint: checkpoint, normalizationState: nil)
            XCTFail("Expected constraint failure")
        } catch {
            let eventCount = try await database.eventCount()
            let savedCheckpoint = try await database.checkpoint(for: checkpoint.sourcePath)
            XCTAssertEqual(eventCount, 0)
            XCTAssertNil(savedCheckpoint)
        }
    }


    func testClearHistoryPersistsCutoffAndRebuildPreservesIt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("db.sqlite"))
        let cutoff = Date(timeIntervalSince1970: 1_800_000_000)

        try await database.clearLocalHistory(at: cutoff)
        let savedCutoff = try await database.importCutoff()
        XCTAssertEqual(savedCutoff, cutoff)
        try await database.rebuildStatistics()
        let cutoffAfterRebuild = try await database.importCutoff()
        XCTAssertEqual(cutoffAfterRebuild, cutoff)
    }

    func testDuplicateEventCannotRegressNormalizationCursor() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("db.sqlite"))
        let checkpoint = SourceCheckpoint(
            sourcePath: "/fixture.jsonl",
            fileIdentity: "1:2",
            generation: 0,
            committedOffset: 100,
            sessionID: "session",
            inheritsHistory: false,
            model: nil,
            projectPath: nil
        )
        let event = UsageEvent(
            eventKey: "same-event",
            occurredAt: Date(timeIntervalSince1970: 1_800_000_100),
            sessionID: "session",
            model: nil,
            projectPath: nil,
            usage: TokenUsage(inputTokens: 150, cachedInputTokens: 90, outputTokens: 30),
            sourcePath: "source",
            sourcePosition: 10
        )
        let latest = UsageNormalizationState(
            cumulativeHighWaterMark: event.usage,
            lastObservedAt: event.occurredAt,
            quality: .exact
        )
        let stale = UsageNormalizationState(
            cumulativeHighWaterMark: TokenUsage(inputTokens: 100, cachedInputTokens: 60, outputTokens: 20),
            lastObservedAt: event.occurredAt.addingTimeInterval(-60),
            quality: .partial
        )

        try await database.commit(events: [event], checkpoint: checkpoint, normalizationState: latest)
        try await database.commit(events: [event], checkpoint: checkpoint, normalizationState: stale)

        let saved = try await database.normalizationState(for: "session")
        XCTAssertEqual(saved, latest)
    }

    func testMaintenanceEpochRejectsAnOlderInFlightScan() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("db.sqlite"))
        let oldEpoch = try await database.dataEpoch()
        try await database.clearLocalHistory(at: Date(timeIntervalSince1970: 1_800_000_000))
        let checkpoint = SourceCheckpoint.fresh(sourcePath: "/stale.jsonl", fileIdentity: "1:1")

        do {
            try await database.commit(
                events: [],
                checkpoint: checkpoint,
                normalizationState: nil,
                expectedEpoch: oldEpoch
            )
            XCTFail("Expected stale scan rejection")
        } catch SQLiteDatabaseError.staleScan {
            let savedCheckpoint = try await database.checkpoint(for: checkpoint.sourcePath)
            XCTAssertNil(savedCheckpoint)
        }
    }

    func testVersion2MigrationPreservesUsageAndHashesSensitiveMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("db.sqlite")
        let database = try SQLiteDatabase(url: url)
        let cutoff = Date(timeIntervalSince1970: 1_799_999_000)
        try await database.clearLocalHistory(at: cutoff)

        let rawSessionID = "raw-session-id"
        let checkpoint = SourceCheckpoint(
            sourcePath: "/Users/example/.codex/sessions/fixture.jsonl",
            fileIdentity: "1:2",
            generation: 0,
            committedOffset: 100,
            sessionID: rawSessionID,
            inheritsHistory: false,
            model: "private-model",
            projectPath: "/private/project"
        )
        let usage = TokenUsage(inputTokens: 100, cachedInputTokens: 60, outputTokens: 20)
        let eventDate = Date(timeIntervalSince1970: 1_800_000_000)
        let event = UsageEvent(
            eventKey: "stable-event",
            occurredAt: eventDate,
            sessionID: rawSessionID,
            model: "private-model",
            projectPath: "/private/project",
            usage: usage,
            sourcePath: checkpoint.sourcePath,
            sourcePosition: 10
        )
        try await database.commit(
            events: [event],
            checkpoint: checkpoint,
            normalizationState: UsageNormalizationState(
                cumulativeHighWaterMark: usage,
                lastObservedAt: eventDate,
                quality: .exact
            )
        )
        try await database.prepareVersion2FixtureForTesting()

        let migrated = try SQLiteDatabase(url: url)
        let migratedCount = try await migrated.eventCount()
        let migratedCutoff = try await migrated.importCutoff()
        XCTAssertEqual(migratedCount, 1)
        XCTAssertEqual(migratedCutoff, cutoff)
        let snapshot = try await migrated.usageSnapshot(
            now: eventDate.addingTimeInterval(60),
            calendar: Calendar(identifier: .gregorian),
            weekStart: .monday
        )
        XCTAssertEqual(snapshot.allTime, usage)

        let digest = SHA256.hash(data: Data(rawSessionID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let migratedState = try await migrated.normalizationState(for: digest)
        let rawState = try await migrated.normalizationState(for: rawSessionID)
        XCTAssertEqual(migratedState.cumulativeHighWaterMark, usage)
        XCTAssertEqual(rawState, .empty)
        let migratedCheckpoint = try await migrated.checkpoint(for: checkpoint.sourcePath)
        XCTAssertEqual(migratedCheckpoint?.sessionID, digest)
        XCTAssertNil(migratedCheckpoint?.model)
        XCTAssertNil(migratedCheckpoint?.projectPath)
    }

    func testDatabaseFilesUseOwnerOnlyPermissions() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("db.sqlite")
        _ = try SQLiteDatabase(url: url)

        let directoryMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber
        ).intValue & 0o777
        let databaseMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        ).intValue & 0o777
        XCTAssertEqual(directoryMode, 0o700)
        XCTAssertEqual(databaseMode, 0o600)
    }
}
