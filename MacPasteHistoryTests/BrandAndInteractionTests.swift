import XCTest
@testable import MacPasteHistory

final class BrandAndInteractionTests: XCTestCase {
    func testAppBrand_shouldUseZhanYiAsDisplayName() {
        XCTAssertEqual(AppBrand.displayName, "粘易")
    }

    func testHistoryRowInteraction_whenSingleClicked_shouldPasteImmediately() {
        XCTAssertEqual(HistoryRowInteraction.primaryAction, .paste)
    }
}
