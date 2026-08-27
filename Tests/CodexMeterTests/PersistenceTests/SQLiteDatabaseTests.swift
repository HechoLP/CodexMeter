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
        XCTAssertEqual(reopenedEventCount, 1)
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
}
