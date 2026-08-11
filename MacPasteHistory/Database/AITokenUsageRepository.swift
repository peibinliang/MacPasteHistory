import Foundation
import SQLite3

enum AITokenUsageRepositoryError: Error, Equatable {
    case invalidRecord
}

final class AITokenUsageRepository {
    private let database: DatabaseConnection
    private let dateFormatter = DateFormatter.sqliteDateFormatter

    init(database: DatabaseConnection) {
        self.database = database
    }

    @discardableResult
    func insert(_ record: AITokenUsageRecord) throws -> Bool {
        try validate(record)
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO ai_token_usage (
                request_id, provider, model_identifier, input_tokens, output_tokens,
                total_tokens, cached_input_tokens, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindText(record.requestID, to: statement, index: 1)
        try bindText(record.provider, to: statement, index: 2)
        try bindText(record.modelIdentifier, to: statement, index: 3)
        try bindInt(record.inputTokens, to: statement, index: 4)
        try bindInt(record.outputTokens, to: statement, index: 5)
        try bindInt(record.totalTokens, to: statement, index: 6)
        if let cachedInputTokens = record.cachedInputTokens {
            try bindInt(cachedInputTokens, to: statement, index: 7)
        } else {
            guard sqlite3_bind_null(statement, 7) == SQLITE_OK else {
                throw DatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
        try bindText(dateFormatter.string(from: record.createdAt), to: statement, index: 8)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        guard let handle = database.handle else {
            throw DatabaseError.stepFailed("Database is closed")
        }
        return sqlite3_changes(handle) == 1
    }

    func summary(modelIdentifier: String? = nil) throws -> AITokenUsageSummary {
        let hasModelFilter = modelIdentifier?.isEmpty == false
        let statement = try database.prepare(
            """
            SELECT COUNT(*),
                   COALESCE(SUM(input_tokens), 0),
                   COALESCE(SUM(output_tokens), 0),
                   COALESCE(SUM(total_tokens), 0),
                   COALESCE(SUM(cached_input_tokens), 0)
            FROM ai_token_usage
            \(hasModelFilter ? "WHERE model_identifier = ?" : "");
            """
        )
        defer { sqlite3_finalize(statement) }

        if let modelIdentifier, hasModelFilter {
            try bindText(modelIdentifier, to: statement, index: 1)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return AITokenUsageSummary(
            requestCount: Int(sqlite3_column_int64(statement, 0)),
            inputTokens: Int(sqlite3_column_int64(statement, 1)),
            outputTokens: Int(sqlite3_column_int64(statement, 2)),
            totalTokens: Int(sqlite3_column_int64(statement, 3)),
            cachedInputTokens: Int(sqlite3_column_int64(statement, 4))
        )
    }

    func deleteAll() throws {
        try database.execute("DELETE FROM ai_token_usage;")
    }

    private func validate(_ record: AITokenUsageRecord) throws {
        let hasInvalidText = record.requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || record.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || record.modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasNegativeCount = record.inputTokens < 0
            || record.outputTokens < 0
            || record.totalTokens < 0
            || (record.cachedInputTokens ?? 0) < 0
        guard hasInvalidText == false, hasNegativeCount == false else {
            throw AITokenUsageRepositoryError.invalidRecord
        }
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, index: Int32) throws {
        guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    private func bindInt(_ value: Int, to statement: OpaquePointer?, index: Int32) throws {
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
