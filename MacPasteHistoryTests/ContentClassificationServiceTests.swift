import XCTest

@testable import MacPasteHistory

final class ContentClassificationServiceTests: XCTestCase {
    func testEffectiveType_preservesUserOverride() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let database = try DatabaseConnection(databaseURL: url)
        defer { try? database.close(); try? FileManager.default.removeItem(at: url) }
        try MigrationManager(database: database).migrate()
        let repository = ClipboardHistoryRepository(database: database)
        let item = try repository.saveText("SELECT id FROM users", sourceApp: nil, sourceBundleID: nil)
        try repository.updateUserOverrideType(id: item.id, type: .url)

        let reloaded = try XCTUnwrap(repository.historyItem(id: item.id))
        let service = ContentClassificationService(databaseURL: url)

        let effectiveType = await service.effectiveType(for: reloaded)
        XCTAssertEqual(effectiveType, .url)
    }
}
