import XCTest
@testable import MacPasteHistory

final class ContentActionRegistryTests: XCTestCase {
    func testDefaultRegistry_hasUniqueStableIDsAndSearchableActions() {
        let registry = ContentActionRegistry()
        XCTAssertEqual(Set(registry.actions.map(\.id)).count, registry.actions.count)
        XCTAssertNotNil(registry.action(id: ContentActionID(rawValue: "json.format")))
        XCTAssertTrue(registry.search("FORMAT").contains { $0.id.rawValue == "json.format" })
        XCTAssertEqual(registry.sorted.map(\.id), registry.sorted.map(\.id).sorted())
    }
}
