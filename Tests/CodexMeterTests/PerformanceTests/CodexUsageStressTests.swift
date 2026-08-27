import Foundation
import XCTest
@testable import CodexMeter

final class CodexUsageStressTests: XCTestCase {
    func testLargeHistoryStreamingAndIncrementalReplay() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CODEXMETER_RUN_STRESS_TESTS"] == "1",
            "Set CODEXMETER_RUN_STRESS_TESTS=1 to run the 10k/100k history stress suite."
        )

        try await verifyHistory(eventCount: 10_000)
        try await verifyHistory(eventCount: 100_000)
    }

    private func verifyHistory(eventCount: Int) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        let source = sessions.appendingPathComponent(
            "rollout-2026-08-27T00-00-00-\(sessionID).jsonl"
        )
        _ = FileManager.default.createFile(atPath: source.path, contents: nil)
        let handle = try FileHandle(forWritingTo: source)
        var output = Data(
            "{\"timestamp\":\"2026-08-27T00:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"\(sessionID)\"}}\n".utf8
        )
        for index in 1...eventCount {
            let cached = index / 2
            let generated = index / 4
            let line =
                "{\"timestamp\":\"2026-08-27T00:01:00Z\",\"type\":\"event_msg\",\"ordinal\":\(index),\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":\(index),\"cached_input_tokens\":\(cached),\"output_tokens\":\(generated)},\"last_token_usage\":{\"input_tokens\":\(index == 1 ? 1 : 0),\"cached_input_tokens\":0,\"output_tokens\":0}}}}\n"
            output.append(contentsOf: line.utf8)
            if output.count >= 1_048_576 {
                try handle.write(contentsOf: output)
                output.removeAll(keepingCapacity: true)
            }
        }
        if !output.isEmpty {
            try handle.write(contentsOf: output)
        }
        try handle.close()

        let database = try SQLiteDatabase(url: root.appendingPathComponent("usage.sqlite"))
        let collector = CodexUsageCollector(database: database, roots: [sessions])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try Date.ISO8601FormatStyle().parse("2026-08-27T01:00:00Z")
        let startedAt = Date()
        var initial = try await collector.refresh(now: now, calendar: calendar, weekStart: .monday)
        var continuationCount = 0
        while initial.hasMoreWork {
            continuationCount += 1
            XCTAssertLessThan(continuationCount, 100, "Bounded import did not converge")
            initial = try await collector.refresh(now: now, calendar: calendar, weekStart: .monday)
        }
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertEqual(initial.snapshot.allTime.inputTokens, Int64(eventCount))
        XCTAssertEqual(initial.snapshot.allTime.cachedInputTokens, Int64(eventCount / 2))
        XCTAssertEqual(initial.snapshot.allTime.outputTokens, Int64(eventCount / 4))
        let initialEventCount = try await database.eventCount()
        XCTAssertEqual(initialEventCount, Int64(eventCount))

        let replay = try await collector.refresh(now: now, calendar: calendar, weekStart: .monday)
        XCTAssertEqual(replay.processedBytes, 0)
        let replayedEventCount = try await database.eventCount()
        XCTAssertEqual(replayedEventCount, Int64(eventCount))
        print(
            "CodexMeter stress: \(eventCount) events in \(String(format: "%.3f", elapsed))s "
                + "(\(String(format: "%.0f", Double(eventCount) / max(elapsed, 0.001))) events/s)"
        )
    }
}
