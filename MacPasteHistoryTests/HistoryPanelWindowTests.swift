import AppKit
import XCTest
@testable import MacPasteHistory

@MainActor
final class HistoryPanelWindowTests: XCTestCase {
    func testInit_shouldConfigureNonactivatingFullscreenOverlayBehavior() {
        let panel = HistoryPanelWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 480))

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertTrue(panel.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(panel.styleMask.contains(.titled))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.transient))
        XCTAssertEqual(panel.level, .popUpMenu)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.isOpaque)
    }

    func testTopCenteredFrame_shouldPositionPanelBelowScreenTopEdge() {
        let screenFrame = NSRect(x: 100, y: 50, width: 1_440, height: 900)

        let frame = HistoryPanelWindow.topCenteredFrame(
            panelSize: NSSize(width: 720, height: 480),
            screenFrame: screenFrame,
            topInset: 12
        )

        XCTAssertEqual(frame.origin.x, 460)
        XCTAssertEqual(frame.origin.y, 458)
        XCTAssertEqual(frame.size, NSSize(width: 720, height: 480))
    }
}
