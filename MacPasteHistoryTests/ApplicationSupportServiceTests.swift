import XCTest
@testable import MacPasteHistory

final class ApplicationSupportServiceTests: XCTestCase {
    func testApplicationSupportURL_whenOverrideIsProvided_shouldUseOverrideDirectory() throws {
        let overrideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let service = ApplicationSupportService(applicationSupportOverrideURL: overrideURL)

        XCTAssertEqual(try service.applicationSupportURL, overrideURL)
        XCTAssertEqual(try service.databaseURL, overrideURL.appendingPathComponent("clipboard.db", isDirectory: false))
        XCTAssertEqual(try service.imagesURL, overrideURL.appendingPathComponent("images", isDirectory: true))
        XCTAssertEqual(try service.thumbnailsURL, overrideURL.appendingPathComponent("thumbnails", isDirectory: true))
        XCTAssertEqual(
            try service.reconciliationTemporaryURL,
            overrideURL.appendingPathComponent("temporary", isDirectory: true)
        )
        XCTAssertEqual(try service.logsURL, overrideURL.appendingPathComponent("logs", isDirectory: true))
    }

    func testCreateRequiredDirectories_shouldCreateReconciliationTemporaryDirectory() throws {
        let overrideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: overrideURL) }
        let service = ApplicationSupportService(applicationSupportOverrideURL: overrideURL)

        try service.createRequiredDirectories()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: try service.reconciliationTemporaryURL.path,
                isDirectory: &isDirectory
            )
        )
        XCTAssertTrue(isDirectory.boolValue)
    }
}
