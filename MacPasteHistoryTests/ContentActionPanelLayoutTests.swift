import AppKit
import XCTest
@testable import MacPasteHistory

@MainActor
final class ContentActionPanelLayoutTests: XCTestCase {
    func testLayoutMode_usesExpandedOnlyWhenSideInsetsFit() {
        XCTAssertEqual(HistoryPanelWindow.layoutMode(availableWidth: 1_287), .overlay)
        XCTAssertEqual(HistoryPanelWindow.layoutMode(availableWidth: 1_288), .expanded)
    }

    func testPanelSize_usesPreferredExpandedWidthAndDefaultOverlayWidth() {
        let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)

        XCTAssertEqual(HistoryPanelWindow.panelSize(for: .expanded, screenVisibleFrame: screen), NSSize(width: 1_240, height: 620))
        XCTAssertEqual(HistoryPanelWindow.panelSize(for: .overlay, screenVisibleFrame: screen), HistoryPanelWindow.defaultSize)
    }
}
