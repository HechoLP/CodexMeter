import Foundation
import XCTest
@testable import CodexMeter

final class CodexJSONLParserTests: XCTestCase {
    private let parser = CodexJSONLParser()

    func testParsesObservedTokenEventAndDoesNotDoubleCountCachedInput() throws {
        let line = #"{"timestamp":"2026-08-27T01:02:03.456Z","type":"event_msg","ordinal":42,"payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1200,"cached_input_tokens":800,"output_tokens":300,"total_tokens":1500},"last_token_usage":{"input_tokens":200,"cached_input_tokens":150,"output_tokens":50,"total_tokens":250}}}}"#

        guard case let .token(event) = parser.parse(Data(line.utf8)) else {
            return XCTFail("Expected token event")
        }

        XCTAssertEqual(event.ordinal, 42)
        XCTAssertEqual(event.lastUsage, TokenUsage(inputTokens: 200, cachedInputTokens: 150, outputTokens: 50))
        XCTAssertEqual(event.lastUsage?.totalTokens, 250)
        XCTAssertEqual(event.cumulativeUsage?.totalTokens, 1_500)
    }

    func testUnknownEventIsIgnored() {
        let line = #"{"timestamp":"2026-08-27T01:02:03Z","type":"event_msg","payload":{"type":"unknown_future_event","new_field":true}}"#
        XCTAssertEqual(parser.parse(Data(line.utf8)), .ignored)
    }

    func testMalformedAndOversizedLinesFailSafely() {
        XCTAssertEqual(parser.parse(Data(#"{"type": "#.utf8)), .malformed("invalid JSON"))
        XCTAssertEqual(
            parser.parse(Data(repeating: 65, count: CodexJSONLParser.maximumLineBytes + 1)),
            .malformed("line exceeds the 1 MiB safety limit")
        )
    }

    func testRejectsImpossibleCachedInput() {
        let line = #"{"timestamp":"2026-08-27T01:02:03Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":11,"output_tokens":2}}}}"#
        XCTAssertEqual(parser.parse(Data(line.utf8)), .malformed("token event has no supported usage object"))
    }

    func testParsesSessionMetadataWithoutConversationContent() {
        let line = #"{"timestamp":"2026-08-27T01:02:03Z","type":"session_meta","payload":{"id":"session-1","cwd":"/tmp/project","model":"gpt-example","unrelated":"ignored"}}"#
        XCTAssertEqual(
            parser.parse(Data(line.utf8)),
            .sessionMetadata(SessionMetadata(id: "session-1", model: "gpt-example", workingDirectory: "/tmp/project"))
        )
    }

    func testParsesTurnContextModelAndWorkingDirectory() {
        let line = #"{"timestamp":"2026-08-27T01:02:03Z","type":"turn_context","payload":{"model":"gpt-example","cwd":"/tmp/project","content":"ignored"}}"#
        XCTAssertEqual(
            parser.parse(Data(line.utf8)),
            .turnContext(TurnContextMetadata(model: "gpt-example", workingDirectory: "/tmp/project"))
        )
    }
}
