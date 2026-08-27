import Foundation

struct UsageEvent: Equatable, Sendable {
    let eventKey: String
    let occurredAt: Date
    let sessionID: String?
    let model: String?
    let projectPath: String?
    let usage: TokenUsage
    let sourcePath: String
    let sourcePosition: Int64
}

struct SessionMetadata: Equatable, Sendable {
    let id: String?
    let model: String?
    let workingDirectory: String?
    let forkedFromID: String?
    let parentThreadID: String?
    let subagentHistoryStartOrdinal: Int64?
    let occurredAt: Date?

    init(
        id: String?,
        model: String?,
        workingDirectory: String?,
        forkedFromID: String? = nil,
        parentThreadID: String? = nil,
        subagentHistoryStartOrdinal: Int64? = nil,
        occurredAt: Date? = nil
    ) {
        self.id = id
        self.model = model
        self.workingDirectory = workingDirectory
        self.forkedFromID = forkedFromID
        self.parentThreadID = parentThreadID
        self.subagentHistoryStartOrdinal = subagentHistoryStartOrdinal
        self.occurredAt = occurredAt
    }

    var inheritsHistory: Bool {
        forkedFromID != nil || parentThreadID != nil || subagentHistoryStartOrdinal != nil
    }
}
