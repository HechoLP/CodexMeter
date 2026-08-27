import CSQLite
import CryptoKit
import Foundation

struct SourceCheckpoint: Equatable, Sendable {
    let sourcePath: String
    var fileIdentity: String
    var generation: Int64
    var committedOffset: Int64
    var sessionID: String?
    var inheritsHistory: Bool
    var model: String?
    var projectPath: String?

    static func fresh(sourcePath: String, fileIdentity: String, generation: Int64 = 0) -> SourceCheckpoint {
        SourceCheckpoint(
            sourcePath: sourcePath,
            fileIdentity: fileIdentity,
            generation: generation,
            committedOffset: 0,
            sessionID: nil,
            inheritsHistory: false,
            model: nil,
            projectPath: nil
        )
    }
}

enum SQLiteDatabaseError: Error, LocalizedError {
    case open(String)
    case statement(String)
    case step(String)
    case migration(String)
    case staleScan

    var errorDescription: String? {
        switch self {
        case let .open(message): "Unable to open usage database: \(message)"
        case let .statement(message): "Database statement failed: \(message)"
        case let .step(message): "Database operation failed: \(message)"
        case let .migration(message): "Database migration failed: \(message)"
        case .staleScan: "The source scan was superseded by a data maintenance operation"
        }
    }
}

actor SQLiteDatabase {
    private let databaseURL: URL
    private var connection: SQLiteConnection?

    init(url: URL) throws {
        databaseURL = url
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let database else {
            let message = database.flatMap { sqlite3_errmsg($0) }.map(String.init(cString:)) ?? "unknown error"
            if let database { sqlite3_close(database) }
            throw SQLiteDatabaseError.open(message)
        }

        connection = SQLiteConnection(rawValue: database)
        do {
            try Self.configure(database)
            try Self.migrate(database)
            try Self.protectDatabaseFiles(at: url)
        } catch {
            sqlite3_close(database)
            connection = nil
            throw error
        }
    }

    deinit {
        if let connection {
            sqlite3_close(connection.rawValue)
        }
    }

    func checkpoint(for sourcePath: String) throws -> SourceCheckpoint? {
        let statement = try prepare(
            """
            SELECT file_identity, generation, committed_offset, session_id,
                   inherits_history, model, project_path
            FROM parsing_state
            WHERE source_path = ?1
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(sourcePath, at: 1, to: statement)

        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            return SourceCheckpoint(
                sourcePath: sourcePath,
                fileIdentity: text(statement, column: 0) ?? "",
                generation: sqlite3_column_int64(statement, 1),
                committedOffset: sqlite3_column_int64(statement, 2),
                sessionID: text(statement, column: 3),
                inheritsHistory: sqlite3_column_int(statement, 4) != 0,
                model: text(statement, column: 5),
                projectPath: text(statement, column: 6)
            )
        case SQLITE_DONE:
            return nil
        default:
            throw SQLiteDatabaseError.step(errorMessage)
        }
    }

    func normalizationState(for sessionID: String) throws -> UsageNormalizationState {
        let statement = try prepare(
            """
            SELECT input_tokens, cached_input_tokens, output_tokens, last_observed_at, quality
            FROM session_counters
            WHERE session_id = ?1
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(sessionID, at: 1, to: statement)

        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            return UsageNormalizationState(
                cumulativeHighWaterMark: TokenUsage(
                    inputTokens: sqlite3_column_int64(statement, 0),
                    cachedInputTokens: sqlite3_column_int64(statement, 1),
                    outputTokens: sqlite3_column_int64(statement, 2)
                ),
                lastObservedAt: sqlite3_column_type(statement, 3) == SQLITE_NULL
                    ? nil
                    : Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                quality: DataQuality(rawValue: text(statement, column: 4) ?? "") ?? .partial
            )
        case SQLITE_DONE:
            return .empty
        default:
            throw SQLiteDatabaseError.step(errorMessage)
        }
    }

    func commit(
        events: [UsageEvent],
        checkpoint: SourceCheckpoint,
        normalizationState: UsageNormalizationState?,
        expectedEpoch: Int64? = nil
    ) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            if let expectedEpoch, try dataEpochWithinTransaction() != expectedEpoch {
                throw SQLiteDatabaseError.staleScan
            }
            var insertedEventCount = 0
            let insert = try prepare(
                """
                INSERT INTO usage_events (
                    event_key, occurred_at, session_id, model, project_path,
                    input_tokens, cached_input_tokens, output_tokens,
                    source_path, source_generation, source_position
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
                ON CONFLICT DO NOTHING
                """
            )
            defer { sqlite3_finalize(insert) }

            for event in events {
                sqlite3_reset(insert)
                sqlite3_clear_bindings(insert)
                try bind(event.eventKey, at: 1, to: insert)
                sqlite3_bind_double(insert, 2, event.occurredAt.timeIntervalSince1970)
                try bind(event.sessionID, at: 3, to: insert)
                try bind(event.model, at: 4, to: insert)
                try bind(event.projectPath, at: 5, to: insert)
                sqlite3_bind_int64(insert, 6, event.usage.inputTokens)
                sqlite3_bind_int64(insert, 7, event.usage.cachedInputTokens)
                sqlite3_bind_int64(insert, 8, event.usage.outputTokens)
                try bind(event.sourcePath, at: 9, to: insert)
                sqlite3_bind_int64(insert, 10, checkpoint.generation)
                sqlite3_bind_int64(insert, 11, event.sourcePosition)
                guard sqlite3_step(insert) == SQLITE_DONE else {
                    throw SQLiteDatabaseError.step(errorMessage)
                }
                if let connection {
                    insertedEventCount += Int(sqlite3_changes(connection.rawValue))
                }
            }

            if (events.isEmpty || insertedEventCount > 0),
               let sessionID = checkpoint.sessionID, let normalizationState,
               let highWaterMark = normalizationState.cumulativeHighWaterMark {
                let counter = try prepare(
                    """
                    INSERT INTO session_counters (
                        session_id, input_tokens, cached_input_tokens, output_tokens,
                        last_observed_at, quality
                    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6)
                    ON CONFLICT(session_id) DO UPDATE SET
                        input_tokens = excluded.input_tokens,
                        cached_input_tokens = excluded.cached_input_tokens,
                        output_tokens = excluded.output_tokens,
                        last_observed_at = excluded.last_observed_at,
                        quality = excluded.quality
                    """
                )
                defer { sqlite3_finalize(counter) }
                try bind(sessionID, at: 1, to: counter)
                sqlite3_bind_int64(counter, 2, highWaterMark.inputTokens)
                sqlite3_bind_int64(counter, 3, highWaterMark.cachedInputTokens)
                sqlite3_bind_int64(counter, 4, highWaterMark.outputTokens)
                if let lastObservedAt = normalizationState.lastObservedAt {
                    sqlite3_bind_double(counter, 5, lastObservedAt.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(counter, 5)
                }
                try bind(normalizationState.quality.rawValue, at: 6, to: counter)
                guard sqlite3_step(counter) == SQLITE_DONE else {
                    throw SQLiteDatabaseError.step(errorMessage)
                }
            }

            let state = try prepare(
                """
                INSERT INTO parsing_state (
                    source_path, file_identity, generation, committed_offset,
                    session_id, inherits_history, model, project_path, updated_at
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
                ON CONFLICT(source_path) DO UPDATE SET
                    file_identity = excluded.file_identity,
                    generation = excluded.generation,
                    committed_offset = excluded.committed_offset,
                    session_id = excluded.session_id,
                    inherits_history = excluded.inherits_history,
                    model = excluded.model,
                    project_path = excluded.project_path,
                    updated_at = excluded.updated_at
                """
            )
            defer { sqlite3_finalize(state) }
            try bind(checkpoint.sourcePath, at: 1, to: state)
            try bind(checkpoint.fileIdentity, at: 2, to: state)
            sqlite3_bind_int64(state, 3, checkpoint.generation)
            sqlite3_bind_int64(state, 4, checkpoint.committedOffset)
            try bind(checkpoint.sessionID, at: 5, to: state)
            sqlite3_bind_int(state, 6, checkpoint.inheritsHistory ? 1 : 0)
            try bind(checkpoint.model, at: 7, to: state)
            try bind(checkpoint.projectPath, at: 8, to: state)
            sqlite3_bind_double(state, 9, Date().timeIntervalSince1970)
            guard sqlite3_step(state) == SQLITE_DONE else {
                throw SQLiteDatabaseError.step(errorMessage)
            }

            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func usageSnapshot(now: Date, calendar: Calendar, weekStart: WeekStart) throws -> UsageSnapshot {
        var reportingCalendar = calendar
        reportingCalendar.firstWeekday = weekStart.rawValue
        let today = reportingCalendar.startOfDay(for: now)
        let week = reportingCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let month = reportingCalendar.dateInterval(of: .month, for: now)?.start ?? today

        let todayUsage = try sum(from: today, through: now)
        let weekUsage = try sum(from: week, through: now)
        let monthUsage = try sum(from: month, through: now)
        let allTimeUsage = try sum(from: nil, through: now)
        let lastUpdated = try maximumEventDate()
        let quality = try databaseQuality(hasEvents: lastUpdated != nil)

        return UsageSnapshot(
            today: todayUsage,
            week: weekUsage,
            month: monthUsage,
            allTime: allTimeUsage,
            quality: quality,
            updatedAt: lastUpdated
        )
    }

    func dataStatistics() throws -> DataStatistics {
        let statement = try prepare("SELECT MIN(occurred_at), MAX(occurred_at) FROM usage_events")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.step(errorMessage)
        }
        let oldest = sqlite3_column_type(statement, 0) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
        let newest = sqlite3_column_type(statement, 1) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let size = [databaseURL.path, databaseURL.path + "-wal", databaseURL.path + "-shm"]
            .compactMap { try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? NSNumber }
            .reduce(Int64(0)) { $0 + $1.int64Value }
        return DataStatistics(databaseBytes: size, oldestRecord: oldest, newestRecord: newest)
    }

    func eventCount() throws -> Int64 {
        let statement = try prepare("SELECT COUNT(*) FROM usage_events")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.step(errorMessage)
        }
        return sqlite3_column_int64(statement, 0)
    }

#if DEBUG
    func prepareVersion2FixtureForTesting() throws {
        try execute("ALTER TABLE session_counters DROP COLUMN last_observed_at")
        try execute("PRAGMA user_version = 2")
    }
#endif

    func importCutoff() throws -> Date? {
        let statement = try prepare("SELECT value FROM app_metadata WHERE key = 'import_cutoff'")
        defer { sqlite3_finalize(statement) }
        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            guard let value = text(statement, column: 0), let seconds = TimeInterval(value) else {
                return nil
            }
            return Date(timeIntervalSince1970: seconds)
        case SQLITE_DONE:
            return nil
        default:
            throw SQLiteDatabaseError.step(errorMessage)
        }
    }

    func dataEpoch() throws -> Int64 {
        try dataEpochWithinTransaction()
    }

    func rebuildStatistics() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try incrementDataEpoch()
            try execute("DELETE FROM usage_events")
            try execute("DELETE FROM parsing_state")
            try execute("DELETE FROM session_counters")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func clearLocalHistory(at cutoff: Date) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try incrementDataEpoch()
            try execute("DELETE FROM usage_events")
            try execute("DELETE FROM parsing_state")
            try execute("DELETE FROM session_counters")
            do {
                let statement = try prepare(
                    """
                    INSERT INTO app_metadata(key, value) VALUES('import_cutoff', ?1)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """
                )
                defer { sqlite3_finalize(statement) }
                try bind(String(cutoff.timeIntervalSince1970), at: 1, to: statement)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteDatabaseError.step(errorMessage)
                }
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
        try execute("VACUUM")
    }

    private func dataEpochWithinTransaction() throws -> Int64 {
        let statement = try prepare("SELECT value FROM app_metadata WHERE key = 'data_epoch'")
        defer { sqlite3_finalize(statement) }
        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            return text(statement, column: 0).flatMap(Int64.init) ?? 0
        case SQLITE_DONE:
            return 0
        default:
            throw SQLiteDatabaseError.step(errorMessage)
        }
    }

    private func incrementDataEpoch() throws {
        try execute(
            """
            INSERT INTO app_metadata(key, value) VALUES('data_epoch', '1')
            ON CONFLICT(key) DO UPDATE SET value = CAST(CAST(value AS INTEGER) + 1 AS TEXT)
            """
        )
    }

    private func sum(from start: Date?, through end: Date) throws -> TokenUsage {
        let statement: OpaquePointer
        if start != nil {
            statement = try prepare(
                """
                SELECT input_tokens, cached_input_tokens, output_tokens
                FROM usage_events
                WHERE occurred_at >= ?1 AND occurred_at <= ?2
                """
            )
        } else {
            statement = try prepare(
                """
                SELECT input_tokens, cached_input_tokens, output_tokens
                FROM usage_events
                WHERE occurred_at <= ?1
                """
            )
        }
        defer { sqlite3_finalize(statement) }

        if let start {
            sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)
        } else {
            sqlite3_bind_double(statement, 1, end.timeIntervalSince1970)
        }
        var total = TokenUsage.zero
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                let input = sqlite3_column_int64(statement, 0)
                let cached = sqlite3_column_int64(statement, 1)
                let output = sqlite3_column_int64(statement, 2)
                let (newInput, inputOverflow) = total.inputTokens.addingReportingOverflow(input)
                let (newCached, cachedOverflow) = total.cachedInputTokens.addingReportingOverflow(cached)
                let (newOutput, outputOverflow) = total.outputTokens.addingReportingOverflow(output)
                guard !inputOverflow, !cachedOverflow, !outputOverflow else {
                    throw SQLiteDatabaseError.step("token aggregate exceeds the supported range")
                }
                total = TokenUsage(
                    inputTokens: newInput,
                    cachedInputTokens: newCached,
                    outputTokens: newOutput
                )
            case SQLITE_DONE:
                return total
            default:
                throw SQLiteDatabaseError.step(errorMessage)
            }
        }
    }

    private func maximumEventDate() throws -> Date? {
        let statement = try prepare("SELECT MAX(occurred_at) FROM usage_events")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.step(errorMessage)
        }
        guard sqlite3_column_type(statement, 0) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
    }

    private func databaseQuality(hasEvents: Bool) throws -> DataQuality {
        guard hasEvents else { return .unavailable }
        let statement = try prepare("SELECT 1 FROM session_counters WHERE quality != 'exact' LIMIT 1")
        defer { sqlite3_finalize(statement) }
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return .partial
        case SQLITE_DONE: return .exact
        default: throw SQLiteDatabaseError.step(errorMessage)
        }
    }

    private static func configure(_ database: OpaquePointer) throws {
        guard sqlite3_busy_timeout(database, 2_000) == SQLITE_OK else {
            throw SQLiteDatabaseError.statement(String(cString: sqlite3_errmsg(database)))
        }
        try execute("PRAGMA foreign_keys = ON", on: database)
        try execute("PRAGMA journal_mode = WAL", on: database)
        try execute("PRAGMA synchronous = NORMAL", on: database)
        try execute("PRAGMA secure_delete = ON", on: database)
    }

    private static func migrate(_ database: OpaquePointer) throws {
        var version = try userVersion(database)
        guard version <= 4 else {
            throw SQLiteDatabaseError.migration("database schema is newer than this app supports")
        }

        if version == 0 {
            try migrateToVersion1(database)
            version = 1
        }
        if version == 1 {
            try migrateToVersion2(database)
            version = 2
        }
        if version == 2 {
            try migrateToVersion3(database)
            version = 3
        }
        if version == 3 {
            try migrateToVersion4(database)
        }
    }

    private static func userVersion(_ database: OpaquePointer) throws -> Int32 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
        return sqlite3_column_int(statement, 0)
    }

    private static func migrateToVersion1(_ database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE", on: database)
        do {
            if try userVersion(database) >= 1 {
                try execute("COMMIT", on: database)
                return
            }
            try execute(
                """
                CREATE TABLE usage_events (
                    event_key TEXT PRIMARY KEY NOT NULL,
                    occurred_at REAL NOT NULL,
                    session_id TEXT,
                    model TEXT,
                    project_path TEXT,
                    input_tokens INTEGER NOT NULL CHECK(input_tokens >= 0),
                    cached_input_tokens INTEGER NOT NULL CHECK(cached_input_tokens >= 0 AND cached_input_tokens <= input_tokens),
                    output_tokens INTEGER NOT NULL CHECK(output_tokens >= 0),
                    source_path TEXT NOT NULL,
                    source_generation INTEGER NOT NULL,
                    source_position INTEGER NOT NULL,
                    UNIQUE(source_path, source_generation, source_position)
                )
                """,
                on: database
            )
            try execute(
                "CREATE INDEX usage_events_occurred_at_idx ON usage_events(occurred_at)",
                on: database
            )
            try execute(
                """
                CREATE TABLE parsing_state (
                    source_path TEXT PRIMARY KEY NOT NULL,
                    file_identity TEXT NOT NULL,
                    generation INTEGER NOT NULL,
                    committed_offset INTEGER NOT NULL CHECK(committed_offset >= 0),
                    session_id TEXT,
                    inherits_history INTEGER NOT NULL DEFAULT 0,
                    model TEXT,
                    project_path TEXT,
                    updated_at REAL NOT NULL
                )
                """,
                on: database
            )
            try execute(
                """
                CREATE TABLE session_counters (
                    session_id TEXT PRIMARY KEY NOT NULL,
                    input_tokens INTEGER NOT NULL,
                    cached_input_tokens INTEGER NOT NULL,
                    output_tokens INTEGER NOT NULL,
                    quality TEXT NOT NULL
                )
                """,
                on: database
            )
            try execute("PRAGMA user_version = 1", on: database)
            try execute("COMMIT", on: database)
        } catch {
            try? execute("ROLLBACK", on: database)
            throw error
        }
    }

    private static func migrateToVersion2(_ database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE", on: database)
        do {
            if try userVersion(database) >= 2 {
                try execute("COMMIT", on: database)
                return
            }
            try execute(
                """
                CREATE TABLE app_metadata (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                )
                """,
                on: database
            )
            try execute("PRAGMA user_version = 2", on: database)
            try execute("COMMIT", on: database)
        } catch {
            try? execute("ROLLBACK", on: database)
            throw error
        }
    }

    private static func migrateToVersion3(_ database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE", on: database)
        do {
            if try userVersion(database) >= 3 {
                try execute("COMMIT", on: database)
                return
            }
            let sessionIDs = try distinctTextValues(
                """
                SELECT session_id FROM usage_events WHERE session_id IS NOT NULL
                UNION SELECT session_id FROM parsing_state WHERE session_id IS NOT NULL
                UNION SELECT session_id FROM session_counters
                """,
                on: database
            )
            for sessionID in sessionIDs {
                let digest = stableDigest(sessionID)
                try updateText(
                    "UPDATE usage_events SET session_id = ?1 WHERE session_id = ?2",
                    newValue: digest,
                    oldValue: sessionID,
                    on: database
                )
                try updateText(
                    "UPDATE parsing_state SET session_id = ?1 WHERE session_id = ?2",
                    newValue: digest,
                    oldValue: sessionID,
                    on: database
                )
                try updateText(
                    "UPDATE session_counters SET session_id = ?1 WHERE session_id = ?2",
                    newValue: digest,
                    oldValue: sessionID,
                    on: database
                )
            }

            let eventSourcePaths = try distinctTextValues(
                "SELECT DISTINCT source_path FROM usage_events",
                on: database
            )
            for sourcePath in eventSourcePaths {
                try updateText(
                    "UPDATE usage_events SET source_path = ?1 WHERE source_path = ?2",
                    newValue: stableDigest(sourcePath),
                    oldValue: sourcePath,
                    on: database
                )
            }

            try execute("UPDATE usage_events SET model = NULL, project_path = NULL", on: database)
            try execute("UPDATE parsing_state SET model = NULL, project_path = NULL", on: database)
            try execute("PRAGMA user_version = 3", on: database)
            try execute("COMMIT", on: database)
        } catch {
            try? execute("ROLLBACK", on: database)
            throw error
        }
    }

    private static func migrateToVersion4(_ database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE", on: database)
        do {
            if try userVersion(database) >= 4 {
                try execute("COMMIT", on: database)
                return
            }
            try execute("ALTER TABLE session_counters ADD COLUMN last_observed_at REAL", on: database)
            try execute("PRAGMA user_version = 4", on: database)
            try execute("COMMIT", on: database)
        } catch {
            try? execute("ROLLBACK", on: database)
            throw error
        }
    }

    private static func distinctTextValues(_ sql: String, on database: OpaquePointer) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var values: [String] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let pointer = sqlite3_column_text(statement, 0) else { continue }
                let count = Int(sqlite3_column_bytes(statement, 0))
                values.append(String(decoding: UnsafeBufferPointer(start: pointer, count: count), as: UTF8.self))
            case SQLITE_DONE:
                return values
            default:
                throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
            }
        }
    }

    private static func updateText(
        _ sql: String,
        newValue: String,
        oldValue: String,
        on database: OpaquePointer
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        let newResult = newValue.withCString {
            sqlite3_bind_text(statement, 1, $0, Int32(newValue.utf8.count), sqliteTransient)
        }
        let oldResult = oldValue.withCString {
            sqlite3_bind_text(statement, 2, $0, Int32(oldValue.utf8.count), sqliteTransient)
        }
        guard newResult == SQLITE_OK, oldResult == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func stableDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let connection else { throw SQLiteDatabaseError.statement("database is closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.rawValue, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteDatabaseError.statement(errorMessage)
        }
        return statement
    }

    private func execute(_ sql: String) throws {
        guard let connection else { throw SQLiteDatabaseError.statement("database is closed") }
        try Self.execute(sql, on: connection.rawValue)
    }

    private static func execute(_ sql: String, on database: OpaquePointer) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(error)
            throw SQLiteDatabaseError.statement(message)
        }
    }

    private func bind(_ value: String?, at index: Int32, to statement: OpaquePointer) throws {
        let result: Int32
        if let value {
            guard !value.contains("\0"), value.utf8.count <= Int(Int32.max) else {
                throw SQLiteDatabaseError.statement("text value is not safe to store")
            }
            result = value.withCString {
                sqlite3_bind_text(statement, index, $0, Int32(value.utf8.count), sqliteTransient)
            }
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else { throw SQLiteDatabaseError.statement(errorMessage) }
    }

    private func text(_ statement: OpaquePointer, column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, column))
        return String(decoding: UnsafeBufferPointer(start: pointer, count: count), as: UTF8.self)
    }

    private static func protectDatabaseFiles(at url: URL) throws {
        let paths = [url.path, url.path + "-wal", url.path + "-shm"]
        for path in paths where FileManager.default.fileExists(atPath: path) {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }

    private var errorMessage: String {
        connection.map { String(cString: sqlite3_errmsg($0.rawValue)) } ?? "database is closed"
    }
}

private struct SQLiteConnection: @unchecked Sendable {
    let rawValue: OpaquePointer
}

private var sqliteTransient: sqlite3_destructor_type {
    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
