import CryptoKit
import Darwin
import Foundation

struct CollectorRefreshResult: Sendable {
    let snapshot: UsageSnapshot
    let sourceCount: Int
    let processedBytes: Int64
    let statistics: DataStatistics
}

struct DataStatistics: Equatable, Sendable {
    let databaseBytes: Int64
    let oldestRecord: Date?
    let newestRecord: Date?

    static let empty = DataStatistics(databaseBytes: 0, oldestRecord: nil, newestRecord: nil)
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

    func cachedSnapshot(now: Date = Date(), calendar: Calendar = .current, weekStart: WeekStart) async throws -> UsageSnapshot {
        try await database.usageSnapshot(now: now, calendar: calendar, weekStart: weekStart)
    }

    func refresh(now: Date = Date(), calendar: Calendar = .current, weekStart: WeekStart) async throws -> CollectorRefreshResult {
        let sources = try discovery.discover(in: roots)
        let importCutoff = try await database.importCutoff()
        let dataEpoch = try await database.dataEpoch()
        var processedBytes: Int64 = 0
        for source in sources {
            try Task.checkCancellation()
            processedBytes += try await process(
                source,
                importCutoff: importCutoff,
                expectedEpoch: dataEpoch
            )
        }

        let snapshot = try await database.usageSnapshot(now: now, calendar: calendar, weekStart: weekStart)
        let statistics = try await database.dataStatistics()
        return CollectorRefreshResult(
            snapshot: snapshot,
            sourceCount: sources.count,
            processedBytes: processedBytes,
            statistics: statistics
        )
    }

    func rebuild(now: Date = Date(), calendar: Calendar = .current, weekStart: WeekStart) async throws -> CollectorRefreshResult {
        try await database.rebuildStatistics()
        return try await refresh(now: now, calendar: calendar, weekStart: weekStart)
    }

    func clearLocalHistory(at cutoff: Date = Date(), calendar: Calendar = .current, weekStart: WeekStart) async throws -> CollectorRefreshResult {
        try await database.clearLocalHistory(at: cutoff)
        return try await refresh(now: cutoff, calendar: calendar, weekStart: weekStart)
    }

    private func process(
        _ source: CodexSessionSource,
        importCutoff: Date?,
        expectedEpoch: Int64
    ) async throws -> Int64 {
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
            model: nil,
            workingDirectory: nil,
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
        var openedStat = stat()
        guard fstat(handle.fileDescriptor, &openedStat) == 0,
              (openedStat.st_mode & S_IFMT) == S_IFREG,
              "\(UInt64(openedStat.st_dev)):\(UInt64(openedStat.st_ino))" == source.identity
        else { return 0 }
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
                    pendingEvents: &pendingEvents,
                    importCutoff: importCutoff
                )
                completedLineCount += 1
                consumedThrough = lineBuffer.index(after: newline)
                checkpoint.committedOffset = lineStartOffset
                    + Int64(lineBuffer.distance(from: lineBuffer.startIndex, to: consumedThrough))

                if completedLineCount >= 1_000 || pendingEvents.count >= 256 {
                    try await database.commit(
                        events: pendingEvents,
                        checkpoint: checkpoint,
                        normalizationState: checkpoint.sessionID == nil ? nil : normalizationState,
                        expectedEpoch: expectedEpoch
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

        if skippingOversizedLine {
            checkpoint.committedOffset = readOffset
        }

        if checkpoint.committedOffset > startingOffset {
            try await database.commit(
                events: pendingEvents,
                checkpoint: checkpoint,
                normalizationState: checkpoint.sessionID == nil ? nil : normalizationState,
                expectedEpoch: expectedEpoch
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
        pendingEvents: inout [UsageEvent],
        importCutoff: Date?
    ) async throws {
        guard line.containsASCII("\"token_count\"")
                || line.containsASCII("\"session_meta\"")
                || line.containsASCII("\"turn_context\"")
        else { return }

        switch parser.parse(line) {
        case let .sessionMetadata(parsed):
            guard checkpoint.committedOffset == 0 else { return }
            let resolvedID = parsed.id.map(storageIdentifier) ?? checkpoint.sessionID
            metadata = SessionMetadata(
                id: resolvedID,
                model: nil,
                workingDirectory: nil,
                forkedFromID: parsed.forkedFromID,
                parentThreadID: parsed.parentThreadID,
                subagentHistoryStartOrdinal: parsed.subagentHistoryStartOrdinal
            )
            checkpoint.sessionID = resolvedID
            checkpoint.inheritsHistory = parsed.inheritsHistory
            checkpoint.model = nil
            checkpoint.projectPath = nil
            if resolvedID != loadedStateSessionID, let resolvedID {
                normalizationState = try await database.normalizationState(for: resolvedID)
                loadedStateSessionID = resolvedID
            }

        case .turnContext:
            break

        case let .token(observation):
            let result = normalizer.normalize(observation, metadata: metadata, state: normalizationState)
            normalizationState = result.state
            guard let delta = result.delta, delta != .zero else { return }
            if let importCutoff, observation.occurredAt <= importCutoff { return }
            let sessionID = checkpoint.sessionID
            pendingEvents.append(
                UsageEvent(
                    eventKey: eventKey(
                        sessionID: sessionID,
                        line: line
                    ),
                    occurredAt: observation.occurredAt,
                    sessionID: sessionID,
                    model: nil,
                    projectPath: nil,
                    usage: delta,
                    sourcePath: storageIdentifier(source.url.standardizedFileURL.path),
                    sourcePosition: position
                )
            )

        case .malformed:
            normalizationState.quality = .partial

        case .ignored:
            break
        }
    }

    private func eventKey(
        sessionID: String?,
        line: Data
    ) -> String {
        let material = "session:\(sessionID ?? "unknown")|line:\(storageIdentifier(line))"
        return storageIdentifier(Data(material.utf8))
    }

    private func sessionIdentifierFromFilename(_ url: URL) -> String? {
        let stem = url.deletingPathExtension().lastPathComponent
        guard stem.count >= 36 else { return nil }
        let suffix = String(stem.suffix(36))
        guard let identifier = UUID(uuidString: suffix)?.uuidString.lowercased() else { return nil }
        return storageIdentifier(identifier)
    }

    private func storageIdentifier(_ value: String) -> String {
        storageIdentifier(Data(value.utf8))
    }

    private func storageIdentifier(_ value: Data) -> String {
        SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
    }
}

private extension Data {
    func containsASCII(_ string: String) -> Bool {
        range(of: Data(string.utf8)) != nil
    }
}
