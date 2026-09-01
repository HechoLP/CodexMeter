import Foundation

public struct ClaudeRateLimitWindow: Codable, Equatable, Sendable {
    public let usedPercentage: Double
    public let resetsAt: Date?

    public init(usedPercentage: Double, resetsAt: Date?) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }
}

public struct ClaudeRateLimitSnapshot: Codable, Equatable, Sendable {
    public let fiveHour: ClaudeRateLimitWindow?
    public let sevenDay: ClaudeRateLimitWindow?
    public let fetchedAt: Date

    public init(
        fiveHour: ClaudeRateLimitWindow?,
        sevenDay: ClaudeRateLimitWindow?,
        fetchedAt: Date
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.fetchedAt = fetchedAt
    }
}

public enum ClaudeRateLimitParseError: Error, Equatable {
    case inputTooLarge
    case malformedInput
}

public enum ClaudeRateLimitCodec {
    public static let maximumInputBytes = 1_048_576

    public static func parseStatusLineInput(
        _ data: Data,
        fetchedAt: Date = Date()
    ) throws -> ClaudeRateLimitSnapshot? {
        guard data.count <= maximumInputBytes else { throw ClaudeRateLimitParseError.inputTooLarge }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeRateLimitParseError.malformedInput
        }
        guard let rateLimits = root["rate_limits"] as? [String: Any] else { return nil }
        let fiveHour = window(rateLimits["five_hour"])
        let sevenDay = window(rateLimits["seven_day"])
        guard fiveHour != nil || sevenDay != nil else { return nil }
        return ClaudeRateLimitSnapshot(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            fetchedAt: fetchedAt
        )
    }

    public static func encode(_ snapshot: ClaudeRateLimitSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> ClaudeRateLimitSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(ClaudeRateLimitSnapshot.self, from: data)
    }

    private static func window(_ value: Any?) -> ClaudeRateLimitWindow? {
        guard let object = value as? [String: Any],
              let used = finiteNumber(object["used_percentage"]),
              (0...100).contains(used)
        else { return nil }
        return ClaudeRateLimitWindow(
            usedPercentage: used,
            resetsAt: finiteNumber(object["resets_at"]).map(Date.init(timeIntervalSince1970:))
        )
    }

    private static func finiteNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID()
        else { return nil }
        let result = number.doubleValue
        return result.isFinite ? result : nil
    }
}

public enum ClaudeBridgeOutputPath {
    public static func isAllowed(_ output: URL, applicationSupportDirectory: URL) -> Bool {
        let standardizedOutput = output.standardizedFileURL
        return ["CodexMeter", "CodexMeter-Development"].contains { appDirectory in
            applicationSupportDirectory
                .appendingPathComponent(appDirectory, isDirectory: true)
                .appendingPathComponent("Claude", isDirectory: true)
                .appendingPathComponent("ClaudeLimits.json")
                .standardizedFileURL == standardizedOutput
        }
    }
}
