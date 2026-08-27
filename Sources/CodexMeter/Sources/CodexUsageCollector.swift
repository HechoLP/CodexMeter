import CryptoKit
import Foundation

struct CollectorRefreshResult: Sendable {
    let snapshot: UsageSnapshot
    let sourceCount: Int
    let processedBytes: Int64
}

actor CodexUsageCollector {
    private let database: SQLiteDatabase
    private let roots: [URL]
    private let discovery = CodexSourceDiscovery()
    private let parser = CodexJSONLParser()
    private let normalizer = UsageNormalizer()

    init(database: SQLiteDatabase, roots: [URL]) {
        self.database = database
        self.roots = roots
    }

    func refresh(now: Date = Date(), calendar: Calendar = .current, weekStart: WeekStart) async throws -> CollectorRefreshResult {
        let sources = try discovery.discover(in: roots)
        var processedBytes: Int64 = 0
        for source in sources {
            try Task.checkCancellation()
            processedBytes += try await process(source)
        }

        let snapshot = try await database.usageSnapshot(now: now, calendar: calendar, weekStart: weekStart)
        return CollectorRefreshResult(
            snapshot: snapshot,
            sourceCount: sources.count,
            processedBytes: processedBytes
        )
    }

    private func process(_ source: CodexSessionSource) async throws -> Int64 {
        var checkpoint = try await database.checkpoint(for: source.url.path)
            ?? SourceCheckpoint.fresh(sourcePath: source.url.path, fileIdentity: source.identity)

        if checkpoint.fileIdentity != source.identity || source.size < checkpoint.committedOffset {
            checkpoint = SourceCheckpoint.fresh(
                sourcePath: source.url.path,
                fileIdentity: source.identity,
                generation: checkpoint.generation + 1
            )
        }
        guard source.size > checkpoint.committedOffset else { return 0 }

        if checkpoint.sessionID == nil {
            checkpoint.sessionID = sessionIdentifierFromFilename(source.url)
        }

        var metadata = SessionMetadata(
            id: checkpoint.sessionID,
            model: checkpoint.model,
            workingDirectory: checkpoint.projectPath,
            forkedFromID: checkpoint.inheritsHistory ? "inherited" : nil
        )
        var normalizationState = if let sessionID = checkpoint.sessionID {
            try await database.normalizationState(for: sessionID)
        } else {
            UsageNormalizationState.empty
        }
        var loadedStateSessionID = checkpoint.sessionID
        var pendingEvents: [UsageEvent] = []
        pendingEvents.reserveCapacity(256)
        var completedLineCount = 0
        let startingOffset = checkpoint.committedOffset

        let handle = try FileHandle(forReadingFrom: source.url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(checkpoint.committedOffset))

        var lineBuffer = Data()
        lineBuffer.reserveCapacity(64 * 1024)
        var lineStartOffset = checkpoint.committedOffset
        var readOffset = checkpoint.committedOffset
        var skippingOversizedLine = false

        while let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            let chunkStartOffset = readOffset
            readOffset += Int64(chunk.count)

            if skippingOversizedLine {
                if let newline = chunk.firstIndex(of: 0x0A) {
                    let afterNewline = chunk.index(after: newline)
                    let consumed = chunk.distance(from: chunk.startIndex, to: afterNewline)
                    checkpoint.committedOffset = chunkStartOffset + Int64(consumed)
                    lineStartOffset = checkpoint.committedOffset
                    skippingOversizedLine = false
                    lineBuffer.append(contentsOf: chunk[afterNewline...])
                } else {
                    continue
                }
            } else {
                lineBuffer.append(chunk)
            }

            var consumedThrough = lineBuffer.startIndex
            while let newline = lineBuffer[consumedThrough...].firstIndex(of: 0x0A) {
                let line = Data(lineBuffer[consumedThrough..<newline])
                let linePosition = lineStartOffset + Int64(lineBuffer.distance(from: lineBuffer.startIndex, to: consumedThrough))
                try await processLine(
                    line,
                    position: linePosition,
                    source: source,
                    checkpoint: &checkpoint,
                    metadata: &metadata,
                    normalizationState: &normalizationState,
                    loadedStateSessionID: &loadedStateSessionID,
                    pendingEvents: &pendingEvents
                )
                completedLineCount += 1
                consumedThrough = lineBuffer.index(after: newline)
                checkpoint.committedOffset = lineStartOffset
                    + Int64(lineBuffer.distance(from: lineBuffer.startIndex, to: consumedThrough))

                if completedLineCount >= 1_000 || pendingEvents.count >= 256 {
                    try await database.commit(
                        events: pendingEvents,
                        checkpoint: checkpoint,
                        normalizationState: checkpoint.sessionID == nil ? nil : normalizationState
                    )
                    pendingEvents.removeAll(keepingCapacity: true)
                    completedLineCount = 0
                }
            }

            if consumedThrough != lineBuffer.startIndex {
                let consumedCount = lineBuffer.distance(from: lineBuffer.startIndex, to: consumedThrough)
                lineBuffer.removeSubrange(lineBuffer.startIndex..<consumedThrough)
                lineStartOffset += Int64(consumedCount)
            }

            if lineBuffer.count > CodexJSONLParser.maximumLineBytes {
                lineBuffer.removeAll(keepingCapacity: false)
                skippingOversizedLine = true
            }
        }

        if checkpoint.committedOffset > startingOffset {
            try await database.commit(
                events: pendingEvents,
                checkpoint: checkpoint,
                normalizationState: checkpoint.sessionID == nil ? nil : normalizationState
            )
        }
        return checkpoint.committedOffset - startingOffset
    }

    private func processLine(
        _ line: Data,
        position: Int64,
        source: CodexSessionSource,
        checkpoint: inout SourceCheckpoint,
        metadata: inout SessionMetadata,
        normalizationState: inout UsageNormalizationState,
        loadedStateSessionID: inout String?,
        pendingEvents: inout [UsageEvent]
    ) async throws {
        guard line.containsASCII("\"token_count\"")
                || line.containsASCII("\"session_meta\"")
                || line.containsASCII("\"turn_context\"")
        else { return }

        switch parser.parse(line) {
        case let .sessionMetadata(parsed):
            guard checkpoint.committedOffset == 0 else { return }
            let resolvedID = parsed.id ?? checkpoint.sessionID
            metadata = SessionMetadata(
                id: resolvedID,
                model: parsed.model,
                workingDirectory: parsed.workingDirectory,
                forkedFromID: parsed.forkedFromID,
                parentThreadID: parsed.parentThreadID,
                subagentHistoryStartOrdinal: parsed.subagentHistoryStartOrdinal
            )
            checkpoint.sessionID = resolvedID
            checkpoint.inheritsHistory = parsed.inheritsHistory
            checkpoint.model = parsed.model
            checkpoint.projectPath = parsed.workingDirectory
            if resolvedID != loadedStateSessionID, let resolvedID {
                normalizationState = try await database.normalizationState(for: resolvedID)
                loadedStateSessionID = resolvedID
            }

        case let .turnContext(context):
            checkpoint.model = context.model ?? checkpoint.model
            checkpoint.projectPath = context.workingDirectory ?? checkpoint.projectPath
            metadata = SessionMetadata(
                id: checkpoint.sessionID,
                model: checkpoint.model,
                workingDirectory: checkpoint.projectPath,
                forkedFromID: checkpoint.inheritsHistory ? "inherited" : nil
            )

        case let .token(observation):
            let result = normalizer.normalize(observation, metadata: metadata, state: normalizationState)
            normalizationState = result.state
            guard let delta = result.delta, delta != .zero else { return }
            let sessionID = checkpoint.sessionID
            pendingEvents.append(
                UsageEvent(
                    eventKey: eventKey(
                        sessionID: sessionID,
                        ordinal: observation.ordinal,
                        sourceIdentity: source.identity,
                        generation: checkpoint.generation,
                        position: position
                    ),
                    occurredAt: observation.occurredAt,
                    sessionID: sessionID,
                    model: checkpoint.model,
                    projectPath: checkpoint.projectPath,
                    usage: delta,
                    sourcePath: source.url.path,
                    sourcePosition: position
                )
            )

        case .ignored, .malformed:
            break
        }
    }

    private func eventKey(
        sessionID: String?,
        ordinal: Int64?,
        sourceIdentity: String,
        generation: Int64,
        position: Int64
    ) -> String {
        let material: String
        if let sessionID, let ordinal {
            material = "session:\(sessionID)|ordinal:\(ordinal)"
        } else {
            material = "file:\(sourceIdentity)|generation:\(generation)|offset:\(position)"
        }
        return SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func sessionIdentifierFromFilename(_ url: URL) -> String? {
        let stem = url.deletingPathExtension().lastPathComponent
        guard stem.count >= 36 else { return nil }
        let suffix = String(stem.suffix(36))
        return UUID(uuidString: suffix)?.uuidString.lowercased()
    }
}

private extension Data {
    func containsASCII(_ string: String) -> Bool {
        range(of: Data(string.utf8)) != nil
    }
}
