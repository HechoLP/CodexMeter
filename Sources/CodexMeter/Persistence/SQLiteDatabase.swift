import CSQLite
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

    var errorDescription: String? {
        switch self {
        case let .open(message): "Unable to open usage database: \(message)"
        case let .statement(message): "Database statement failed: \(message)"
        case let .step(message): "Database operation failed: \(message)"
        case let .migration(message): "Database migration failed: \(message)"
        }
    }
}

actor SQLiteDatabase {
    private var connection: SQLiteConnection?

    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
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
            SELECT input_tokens, cached_input_tokens, output_tokens, quality
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
                quality: DataQuality(rawValue: text(statement, column: 3) ?? "") ?? .partial
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
        normalizationState: UsageNormalizationState?
    ) throws {
        try execute("BEGIN IMMEDIATE")
        do {
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
            }

            if let sessionID = checkpoint.sessionID, let normalizationState,
               let highWaterMark = normalizationState.cumulativeHighWaterMark {
                let counter = try prepare(
                    """
                    INSERT INTO session_counters (
                        session_id, input_tokens, cached_input_tokens, output_tokens, quality
                    ) VALUES (?1, ?2, ?3, ?4, ?5)
                    ON CONFLICT(session_id) DO UPDATE SET
                        input_tokens = excluded.input_tokens,
                        cached_input_tokens = excluded.cached_input_tokens,
                        output_tokens = excluded.output_tokens,
                        quality = excluded.quality
                    """
                )
                defer { sqlite3_finalize(counter) }
                try bind(sessionID, at: 1, to: counter)
                sqlite3_bind_int64(counter, 2, highWaterMark.inputTokens)
                sqlite3_bind_int64(counter, 3, highWaterMark.cachedInputTokens)
                sqlite3_bind_int64(counter, 4, highWaterMark.outputTokens)
                try bind(normalizationState.quality.rawValue, at: 5, to: counter)
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

    func eventCount() throws -> Int64 {
        let statement = try prepare("SELECT COUNT(*) FROM usage_events")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.step(errorMessage)
        }
        return sqlite3_column_int64(statement, 0)
    }

    private func sum(from start: Date?, through end: Date) throws -> TokenUsage {
        let statement: OpaquePointer
        if start != nil {
            statement = try prepare(
                """
                SELECT COALESCE(SUM(input_tokens), 0),
                       COALESCE(SUM(cached_input_tokens), 0),
                       COALESCE(SUM(output_tokens), 0)
                FROM usage_events
                WHERE occurred_at >= ?1 AND occurred_at <= ?2
                """
            )
        } else {
            statement = try prepare(
                """
                SELECT COALESCE(SUM(input_tokens), 0),
                       COALESCE(SUM(cached_input_tokens), 0),
                       COALESCE(SUM(output_tokens), 0)
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
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.step(errorMessage)
        }
        return TokenUsage(
            inputTokens: sqlite3_column_int64(statement, 0),
            cachedInputTokens: sqlite3_column_int64(statement, 1),
            outputTokens: sqlite3_column_int64(statement, 2)
        )
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
        try execute("PRAGMA foreign_keys = ON", on: database)
        try execute("PRAGMA journal_mode = WAL", on: database)
        try execute("PRAGMA synchronous = NORMAL", on: database)
        guard sqlite3_busy_timeout(database, 2_000) == SQLITE_OK else {
            throw SQLiteDatabaseError.statement(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func migrate(_ database: OpaquePointer) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteDatabaseError.migration(String(cString: sqlite3_errmsg(database)))
        }
        let version = sqlite3_column_int(statement, 0)
        guard version <= 1 else {
            throw SQLiteDatabaseError.migration("database schema is newer than this app supports")
        }
        guard version == 0 else { return }

        try execute("BEGIN IMMEDIATE", on: database)
        do {
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
            result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else { throw SQLiteDatabaseError.statement(errorMessage) }
    }

    private func text(_ statement: OpaquePointer, column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: pointer)
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
