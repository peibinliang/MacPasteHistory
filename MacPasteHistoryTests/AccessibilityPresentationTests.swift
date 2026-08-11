import XCTest
@testable import MacPasteHistory

final class AccessibilityPresentationTests: XCTestCase {
    func testActionAndOCRPresentationProvideNonEmptyLabels() {
        let labels = [
            ContentActionAccessibilityPresentation.actionHint,
            ContentActionAccessibilityPresentation.resultEditedValue,
            ContentActionAccessibilityPresentation.derivedLabel,
            ContentActionAccessibilityPresentation.ocrRecognizingLabel,
            ContentActionAccessibilityPresentation.ocrRecognizedLabel,
            ContentActionAccessibilityPresentation.ocrFailedLabel,
            ContentActionAccessibilityPresentation.jwtSignatureWarning
        ]
        XCTAssertTrue(labels.allSatisfy { L10n.string($0).isEmpty == false })
        XCTAssertEqual(ContentActionAccessibilityPresentation.actionLabel(TextContentAction(kind: .trim)), L10n.string("text.trim"))
        XCTAssertFalse(L10n.string("ai.action.polish").isEmpty)
        XCTAssertFalse(L10n.string("ai.consent.message").isEmpty)
        XCTAssertFalse(L10n.string("ai.usage.request-summary").isEmpty)
    }
}
