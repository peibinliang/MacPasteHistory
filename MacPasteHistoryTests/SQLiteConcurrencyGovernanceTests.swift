import CryptoKit
import SQLite3
import XCTest

@testable import MacPasteHistory

final class SQLiteConcurrencyGovernanceTests: XCTestCase {
    func testCurrentJournalMode_whenWriteTransactionOverlapsReadOnlySearch_shouldReturnCommittedSnapshot() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = ClipboardHistoryRepository(database: temporary.connection)
        _ = try repository.saveText(
            "committed search row",
            sourceApp: nil,
            sourceBundleID: nil,
            capturedAt: Date(timeIntervalSince1970: 1_786_463_999)
        )
        let provider = SearchCandidateProvider(databaseURL: temporary.url)

        try temporary.connection.execute("BEGIN IMMEDIATE TRANSACTION;")
        defer { try? temporary.connection.execute("ROLLBACK;") }
        try insertRawText("uncommitted search row", hash: "uncommitted-hash", into: temporary.connection)

        let beforeCommit = try await provider.candidates(for: searchRequest("search row"))
        XCTAssertEqual(beforeCommit.map(\.textContent), ["committed search row"])

        try temporary.connection.execute("COMMIT;")
        let afterCommit = try await provider.candidates(for: searchRequest("search row"))
        XCTAssertEqual(afterCommit.map(\.textContent), ["uncommitted search row", "committed search row"])
    }

    func testCurrentJournalMode_whenSecondWriterOverlapsImmediateTransaction_shouldFailWithinBusyTimeout() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let competingWriter = try DatabaseConnection(databaseURL: temporary.url)
        defer { try? competingWriter.close() }

        try temporary.connection.execute("BEGIN IMMEDIATE TRANSACTION;")
        defer { try? temporary.connection.execute("ROLLBACK;") }

        let startedAt = Date()
        XCTAssertThrowsError(
            try competingWriter.inTransaction {
                try insertRawText("blocked writer", hash: "blocked-writer-hash", into: competingWriter)
            }
        )
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.5)
    }

    func testCurrentJournalMode_whenTransactionRollsBackAndDatabaseReopens_shouldPersistOnlyCommittedRows() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = ClipboardHistoryRepository(database: temporary.connection)
        _ = try repository.saveText("committed before rollback", sourceApp: nil, sourceBundleID: nil)

        XCTAssertThrowsError(
            try temporary.connection.inTransaction {
                try insertRawText("rolled back row", hash: "rolled-back-hash", into: temporary.connection)
                throw ExpectedRollback.rollback
            }
        )
        try temporary.connection.close()

        let reopened = try DatabaseConnection(databaseURL: temporary.url)
        defer { try? reopened.close() }
        let reopenedRepository = ClipboardHistoryRepository(database: reopened)

        XCTAssertEqual(
            try reopenedRepository.fetchHistory(query: HistoryQuery()).map(\.textContent),
            ["committed before rollback"]
        )
    }

    func testCurrentJournalMode_whenDatabaseCloses_shouldNotLeaveWALSidecars() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        XCTAssertEqual(try journalMode(in: temporary.connection), "delete")
        _ = try ClipboardHistoryRepository(database: temporary.connection)
            .saveText("sidecar check", sourceApp: nil, sourceBundleID: nil)

        try temporary.connection.close()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.url.path + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.url.path + "-shm"))
    }

    func testAppCreatedV102Build4Fixture_whenReopenedAndMigrated_shouldRetainHistoryAndUsage() throws {
        let fixtureURL = try v102Build4FixtureURL()
        let fixtureDigest = SHA256.hash(data: try Data(contentsOf: fixtureURL))
            .map { String(format: "%02x", $0) }
            .joined()
        XCTAssertEqual(fixtureDigest, "f4bb3d0d099068e455d6caa935365474278350e4311931701120b94a8581c55a")

        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try temporary.connection.close()
        try FileManager.default.removeItem(at: temporary.url)
        try FileManager.default.copyItem(at: fixtureURL, to: temporary.url)

        let reopened = try DatabaseConnection(databaseURL: temporary.url)
        defer { try? reopened.close() }
        try MigrationManager(database: reopened).migrate()
        let repository = ClipboardHistoryRepository(database: reopened)
        let tokenUsage = AITokenUsageRepository(database: reopened)

        XCTAssertEqual(try migrationVersions(in: reopened), [1, 2, 3, 4])
        XCTAssertEqual(try integrityCheck(in: reopened), "ok")
        XCTAssertFalse(try foreignKeyCheckHasRows(in: reopened))
        XCTAssertEqual(try journalMode(in: reopened), "delete")
        let items = try repository.fetchHistory(query: HistoryQuery())
        XCTAssertEqual(items.map(\.textContent), [
            "V1.0.2 build 4 fixture derived",
            "V1.0.2 build 4 fixture source"
        ])
        XCTAssertEqual(Set(items.compactMap(\.sourceApp)), ["Fixture Source"])
        XCTAssertEqual(Set(items.compactMap(\.sourceBundleID)), ["com.example.fixture-source"])
        XCTAssertTrue(items.allSatisfy { $0.filePath == nil && $0.thumbnailPath == nil && $0.ocrText == nil })
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM clipboard_capture_events;", in: reopened), 2)
        XCTAssertEqual(
            try scalarInt(
                "SELECT COUNT(*) FROM clipboard_capture_events WHERE source_bundle_id = 'com.example.fixture-source';",
                in: reopened
            ),
            2
        )
        XCTAssertEqual(try tokenUsage.summary().totalTokens, 12)
    }

    func testWALExperiment_shouldPassSameReadWriteBusyRollbackReopenAndSidecarMatrix() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try setJournalMode("WAL", in: temporary.connection)
        try MigrationManager(database: temporary.connection).migrate()
        _ = try ClipboardHistoryRepository(database: temporary.connection).saveText(
            "wal committed snapshot",
            sourceApp: nil,
            sourceBundleID: nil
        )
        let competingWriter = try DatabaseConnection(databaseURL: temporary.url)

        try temporary.connection.execute("BEGIN IMMEDIATE TRANSACTION;")
        try insertRawText("wal rolled back", hash: "wal-rolled-back", into: temporary.connection)
        let candidates = try await SearchCandidateProvider(databaseURL: temporary.url).candidates(
            for: searchRequest("wal")
        )
        XCTAssertEqual(candidates.map(\.textContent), ["wal committed snapshot"])

        let startedAt = Date()
        XCTAssertThrowsError(
            try competingWriter.inTransaction {
                try insertRawText("wal blocked", hash: "wal-blocked", into: competingWriter)
            }
        )
        let busyWait = Date().timeIntervalSince(startedAt)
        XCTAssertGreaterThanOrEqual(busyWait, 0.8)
        XCTAssertLessThan(busyWait, 2.5)

        try temporary.connection.execute("ROLLBACK;")
        _ = try ClipboardHistoryRepository(database: competingWriter).saveText(
            "wal committed after rollback",
            sourceApp: nil,
            sourceBundleID: nil
        )
        try competingWriter.close()
        try temporary.connection.close()

        let reopened = try DatabaseConnection(databaseURL: temporary.url)
        XCTAssertEqual(try journalMode(in: reopened), "wal")
        XCTAssertEqual(
            try ClipboardHistoryRepository(database: reopened).fetchHistory(query: HistoryQuery()).map(\.textContent),
            ["wal committed after rollback", "wal committed snapshot"]
        )
        try reopened.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.url.path + "-wal"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.url.path + "-shm"))
    }

    private enum ExpectedRollback: Error {
        case rollback
    }

    private func v102Build4FixtureURL() throws -> URL {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "v1-0-2-build4-clipboard", withExtension: "db"),
              url.standardizedFileURL.path.hasPrefix(bundle.bundleURL.standardizedFileURL.path + "/") else {
            throw FixtureError.missingV102Build4Database
        }
        return url
    }

    private enum FixtureError: Error {
        case missingV102Build4Database
    }

    private func insertRawText(_ text: String, hash: String, into database: DatabaseConnection) throws {
        let escapedText = text.replacingOccurrences(of: "'", with: "''")
        let escapedHash = hash.replacingOccurrences(of: "'", with: "''")
        try database.execute(
            """
            INSERT INTO clipboard_history (
                content_type, text_content, content_hash, text_length,
                searchable_text, first_captured_at, last_captured_at, capture_count
            ) VALUES (
                'text', '\(escapedText)', '\(escapedHash)', \(text.count),
                '\(escapedText)', '2026-08-12 00:00:00.000000', '2026-08-12 00:00:00.000000', 1
            );
            """
        )
    }

    private func searchRequest(_ input: String) -> SearchCandidateRequest {
        SearchCandidateRequest(
            parsedQuery: SearchQueryParser().parse(input),
            storageContentType: nil,
            sourceFilter: .all,
            timeRange: .all,
            favoritesOnly: false,
            limit: 20
        )
    }

    private func journalMode(in database: DatabaseConnection) throws -> String {
        let statement = try database.prepare("PRAGMA journal_mode;")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return String(cString: value)
    }

    private func integrityCheck(in database: DatabaseConnection) throws -> String {
        let statement = try database.prepare("PRAGMA integrity_check;")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return String(cString: value)
    }

    private func foreignKeyCheckHasRows(in database: DatabaseConnection) throws -> Bool {
        let statement = try database.prepare("PRAGMA foreign_key_check;")
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func scalarInt(_ sql: String, in database: DatabaseConnection) throws -> Int {
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func setJournalMode(_ mode: String, in database: DatabaseConnection) throws {
        let statement = try database.prepare("PRAGMA journal_mode=\(mode);")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func migrationVersions(in database: DatabaseConnection) throws -> [Int32] {
        let statement = try database.prepare("SELECT version FROM schema_migrations ORDER BY version;")
        defer { sqlite3_finalize(statement) }
        var versions: [Int32] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            versions.append(sqlite3_column_int(statement, 0))
        }
        return versions
    }
}
