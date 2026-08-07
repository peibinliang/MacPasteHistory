import XCTest
@testable import MacPasteHistory

final class ContentActionRegistryTests: XCTestCase {
    func testDefaultRegistry_hasUniqueStableIDsAndSearchableActions() {
        let registry = ContentActionRegistry()
        let expectedIDs = Set([
            "text.trim", "text.remove-empty-lines", "text.deduplicate-lines", "text.single-line", "text.uppercase", "text.lowercase", "text.markdown-code-block",
            "json.format", "json.minify", "json.validate", "json.escape", "json.unescape",
            "url.encode-query-value", "url.decode", "url.extract-host", "url.parse-query",
            "base64.encode", "base64.decode", "base64.decode-url-safe", "base64.validate",
            "jwt.inspect", "timestamp.convert", "sql.single-line", "shell.quote-argument"
        ])
        XCTAssertEqual(Set(registry.actions.map(\.id)).count, registry.actions.count)
        XCTAssertEqual(Set(registry.actions.map(\.id.rawValue)), expectedIDs)
        XCTAssertNotNil(registry.action(id: ContentActionID(rawValue: "json.format")))
        XCTAssertTrue(registry.search("FORMAT").contains { $0.id.rawValue == "json.format" })
        XCTAssertEqual(registry.sorted.map(\.id), registry.sorted.map(\.id).sorted())
    }
}
