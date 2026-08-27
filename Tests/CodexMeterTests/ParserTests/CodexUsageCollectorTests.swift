import Foundation
import XCTest
@testable import CodexMeter

final class CodexUsageCollectorTests: XCTestCase {
    func testIncrementalPartialDuplicateAndTruncationHandling() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let source = sessions.appendingPathComponent("rollout-2026-08-27T00-00-00-11111111-1111-1111-1111-111111111111.jsonl")
        let database = try SQLiteDatabase(url: root.appendingPathComponent("usage.sqlite"))
        let collector = CodexUsageCollector(database: database, roots: [sessions])

        let metadata = #"{"timestamp":"2026-08-27T00:00:00Z","type":"session_meta","payload":{"id":"11111111-1111-1111-1111-111111111111","cwd":"/project"}}"#
        let first = tokenLine(input: 100, cached: 60, output: 20, lastInput: 100, lastCached: 60, lastOutput: 20, ordinal: 1)
        let duplicate = tokenLine(input: 100, cached: 60, output: 20, lastInput: 100, lastCached: 60, lastOutput: 20, ordinal: 2)
        let partial = #"{"timestamp":"2026-08-27T00:03:00Z","type":"event_msg","ordinal":3,"payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":150"#
        try Data((metadata + "\n" + first + "\n" + duplicate + "\n" + partial).utf8).write(to: source)

        let now = try Date.ISO8601FormatStyle().parse("2026-08-27T01:00:00Z")
        let initial = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(initial.snapshot.allTime, TokenUsage(inputTokens: 100, cachedInputTokens: 60, outputTokens: 20))
        let initialEventCount = try await database.eventCount()
        XCTAssertEqual(initialEventCount, 1)

        let completion = #", "cached_input_tokens":90,"output_tokens":30},"last_token_usage":{"input_tokens":50,"cached_input_tokens":30,"output_tokens":10}}}}"#
        let handle = try FileHandle(forWritingTo: source)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((completion + "\n").utf8))
        try handle.close()

        let appended = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(appended.snapshot.allTime, TokenUsage(inputTokens: 150, cachedInputTokens: 90, outputTokens: 30))
        let appendedEventCount = try await database.eventCount()
        XCTAssertEqual(appendedEventCount, 2)

        try Data((metadata + "\n" + first + "\n").utf8).write(to: source)
        let truncated = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(truncated.snapshot.allTime, appended.snapshot.allTime)
        let truncatedEventCount = try await database.eventCount()
        XCTAssertEqual(truncatedEventCount, 2)
    }

    func testNoOrdinalReplayReplacementAndRenameRemainIdempotent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let original = sessions.appendingPathComponent("rollout-2026-08-27T00-00-00-22222222-2222-2222-2222-222222222222.jsonl")
        let renamed = sessions.appendingPathComponent("renamed-rollout.jsonl")
        let database = try SQLiteDatabase(url: root.appendingPathComponent("usage.sqlite"))
        let collector = CodexUsageCollector(database: database, roots: [sessions])
        let metadata = #"{"timestamp":"2026-08-27T00:00:00Z","type":"session_meta","payload":{"id":"22222222-2222-2222-2222-222222222222"}}"#
        let first = tokenLineWithoutOrdinal(
            timestamp: "2026-08-27T00:01:00Z",
            input: 100,
            cached: 60,
            output: 20,
            lastInput: 100,
            lastCached: 60,
            lastOutput: 20
        )
        let second = tokenLineWithoutOrdinal(
            timestamp: "2026-08-27T00:02:00Z",
            input: 150,
            cached: 90,
            output: 30,
            lastInput: 50,
            lastCached: 30,
            lastOutput: 10
        )
        try Data((metadata + "\n" + first + "\n" + second + "\n").utf8).write(to: original)

        let now = try Date.ISO8601FormatStyle().parse("2026-08-27T01:00:00Z")
        let initial = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(initial.snapshot.allTime, TokenUsage(inputTokens: 150, cachedInputTokens: 90, outputTokens: 30))
        let initialCount = try await database.eventCount()
        XCTAssertEqual(initialCount, 2)

        try Data((metadata + "\n" + first + "\n").utf8).write(to: original, options: .atomic)
        let replaced = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(replaced.snapshot.allTime, initial.snapshot.allTime)
        let replacedCount = try await database.eventCount()
        XCTAssertEqual(replacedCount, 2)

        try FileManager.default.moveItem(at: original, to: renamed)
        let afterRename = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(afterRename.snapshot.allTime, initial.snapshot.allTime)
        let renamedCount = try await database.eventCount()
        XCTAssertEqual(renamedCount, 2)
    }

    func testMalformedTokenEventMarksSnapshotPartial() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let source = sessions.appendingPathComponent("rollout-2026-08-27T00-00-00-33333333-3333-3333-3333-333333333333.jsonl")
        let database = try SQLiteDatabase(url: root.appendingPathComponent("usage.sqlite"))
        let collector = CodexUsageCollector(database: database, roots: [sessions])
        let metadata = #"{"timestamp":"2026-08-27T00:00:00Z","type":"session_meta","payload":{"id":"33333333-3333-3333-3333-333333333333"}}"#
        let valid = tokenLineWithoutOrdinal(
            timestamp: "2026-08-27T00:01:00Z",
            input: 100,
            cached: 60,
            output: 20,
            lastInput: 100,
            lastCached: 60,
            lastOutput: 20
        )
        let malformed = #"{"timestamp":"2026-08-27T00:02:00Z","type":"event_msg","payload":{"type":"token_count"}}"#
        try Data((metadata + "\n" + valid + "\n" + malformed + "\n").utf8).write(to: source)

        let now = try Date.ISO8601FormatStyle().parse("2026-08-27T01:00:00Z")
        let result = try await collector.refresh(now: now, calendar: utcCalendar, weekStart: .monday)
        XCTAssertEqual(result.snapshot.quality, .partial)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func tokenLine(
        input: Int64,
        cached: Int64,
        output: Int64,
        lastInput: Int64,
        lastCached: Int64,
        lastOutput: Int64,
        ordinal: Int64
    ) -> String {
        """
        {"timestamp":"2026-08-27T00:01:00Z","type":"event_msg","ordinal":\(ordinal),"payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cached),"output_tokens":\(output)},"last_token_usage":{"input_tokens":\(lastInput),"cached_input_tokens":\(lastCached),"output_tokens":\(lastOutput)}}}}
        """
    }

    private func tokenLineWithoutOrdinal(
        timestamp: String,
        input: Int64,
        cached: Int64,
        output: Int64,
        lastInput: Int64,
        lastCached: Int64,
        lastOutput: Int64
    ) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(input),"cached_input_tokens":\(cached),"output_tokens":\(output)},"last_token_usage":{"input_tokens":\(lastInput),"cached_input_tokens":\(lastCached),"output_tokens":\(lastOutput)}}}}
        """
    }
}
