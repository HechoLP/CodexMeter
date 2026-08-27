import Foundation
import XCTest
@testable import CodexMeter

final class AggregationServiceTests: XCTestCase {
    func testMondayWeekAndPeriodBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27, hour: 12)))

        let events = [
            event(at: calendar.date(byAdding: .hour, value: -1, to: now)!, tokens: 10),
            event(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 9))!, tokens: 20),
            event(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 9))!, tokens: 30),
            event(at: calendar.date(from: DateComponents(year: 2026, month: 7, day: 31, hour: 23))!, tokens: 40)
        ]

        let snapshot = AggregationService().snapshot(
            from: events,
            now: now,
            calendar: calendar,
            weekStart: .monday
        )

        XCTAssertEqual(snapshot.today.totalTokens, 10)
        XCTAssertEqual(snapshot.week.totalTokens, 30)
        XCTAssertEqual(snapshot.month.totalTokens, 60)
        XCTAssertEqual(snapshot.allTime.totalTokens, 100)
    }

    private func event(at date: Date, tokens: Int64) -> UsageEvent {
        UsageEvent(
            eventKey: UUID().uuidString,
            occurredAt: date,
            sessionID: nil,
            model: nil,
            projectPath: nil,
            usage: TokenUsage(inputTokens: tokens, cachedInputTokens: 0, outputTokens: 0),
            sourcePath: "/fixture",
            sourcePosition: 0
        )
    }
}
