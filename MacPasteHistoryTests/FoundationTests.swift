import XCTest
@testable import MacPasteHistory

final class FoundationTests: XCTestCase {
    func testDefaultSettings_shouldUseExpectedInitialRecordingState() {
        XCTAssertTrue(DefaultSettings.shouldRecordText)
        XCTAssertTrue(DefaultSettings.shouldRecordImage)
    }

    func testDefaultSettings_shouldUseBoundedPollingInterval() {
        XCTAssertGreaterThanOrEqual(DefaultSettings.clipboardPollingInterval, 0.3)
        XCTAssertLessThanOrEqual(DefaultSettings.clipboardPollingInterval, 1.0)
    }
}
