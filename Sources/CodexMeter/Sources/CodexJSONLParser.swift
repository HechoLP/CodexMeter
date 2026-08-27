import Foundation

enum CodexParsedLine: Equatable, Sendable {
    case sessionMetadata(SessionMetadata)
    case turnContext(TurnContextMetadata)
    case token(CodexTokenObservation)
    case ignored
    case malformed(String)
}

struct CodexTokenObservation: Equatable, Sendable {
    let occurredAt: Date
    let ordinal: Int64?
    let lastUsage: TokenUsage?
    let cumulativeUsage: TokenUsage?
}

struct TurnContextMetadata: Equatable, Sendable {
    let model: String?
    let workingDirectory: String?
}

struct CodexJSONLParser: Sendable {
    static let maximumLineBytes = 1_048_576

    func parse(_ line: Data) -> CodexParsedLine {
        guard !line.isEmpty else { return .ignored }
        guard line.count <= Self.maximumLineBytes else {
            return .malformed("line exceeds the 1 MiB safety limit")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: line)
        } catch {
            return .malformed("invalid JSON")
        }

        guard let root = object as? [String: Any], let type = root["type"] as? String else {
            return .malformed("missing event type")
        }

        switch type {
        case "session_meta":
            return parseSessionMetadata(root)
        case "turn_context":
            return parseTurnContext(root)
        case "event_msg":
            return parseEventMessage(root)
        default:
            return .ignored
        }
    }

    private func parseTurnContext(_ root: [String: Any]) -> CodexParsedLine {
        guard let payload = root["payload"] as? [String: Any] else {
            return .malformed("turn context is missing payload")
        }
        return .turnContext(
            TurnContextMetadata(
                model: payload["model"] as? String,
                workingDirectory: payload["cwd"] as? String
            )
        )
    }

    private func parseSessionMetadata(_ root: [String: Any]) -> CodexParsedLine {
        guard let payload = root["payload"] as? [String: Any] else {
            return .malformed("session metadata is missing payload")
        }

        return .sessionMetadata(
            SessionMetadata(
                id: payload["id"] as? String,
                model: payload["model"] as? String,
                workingDirectory: payload["cwd"] as? String,
                forkedFromID: payload["forked_from_id"] as? String,
                parentThreadID: payload["parent_thread_id"] as? String,
                subagentHistoryStartOrdinal: integer(payload["subagent_history_start_ordinal"])
            )
        )
    }

    private func parseEventMessage(_ root: [String: Any]) -> CodexParsedLine {
        guard
            let payload = root["payload"] as? [String: Any],
            payload["type"] as? String == "token_count"
        else {
            return .ignored
        }

        guard
            let timestamp = root["timestamp"] as? String,
            let occurredAt = parseTimestamp(timestamp)
        else {
            return .malformed("token event is missing a valid timestamp")
        }

        guard let info = payload["info"] as? [String: Any] else {
            return .ignored
        }

        let lastUsage = parseUsage(info["last_token_usage"])
        let cumulativeUsage = parseUsage(info["total_token_usage"])
        guard lastUsage != nil || cumulativeUsage != nil else {
            return .malformed("token event has no supported usage object")
        }

        return .token(
            CodexTokenObservation(
                occurredAt: occurredAt,
                ordinal: integer(root["ordinal"]),
                lastUsage: lastUsage,
                cumulativeUsage: cumulativeUsage
            )
        )
    }

    private func parseUsage(_ value: Any?) -> TokenUsage? {
        guard let dictionary = value as? [String: Any] else { return nil }
        guard
            let input = integer(dictionary["input_tokens"]),
            let cached = integer(dictionary["cached_input_tokens"]),
            let output = integer(dictionary["output_tokens"])
        else {
            return nil
        }

        let usage = TokenUsage(inputTokens: input, cachedInputTokens: cached, outputTokens: output)
        return usage.isValid ? usage : nil
    }

    private func integer(_ value: Any?) -> Int64? {
        switch value {
        case let number as NSNumber:
            let result = number.int64Value
            return result >= 0 ? result : nil
        case let string as String:
            return Int64(string).flatMap { $0 >= 0 ? $0 : nil }
        default:
            return nil
        }
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let date = try? fractional.parse(value) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }
}
