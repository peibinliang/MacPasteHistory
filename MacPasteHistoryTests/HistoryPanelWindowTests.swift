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
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.isOpaque)
    }

    func testPositionOnActiveScreen_shouldPlacePanelAtTopCenterOfPointerScreen() throws {
        let panel = HistoryPanelWindow(contentRect: NSRect(origin: .zero, size: NSSize(width: 720, height: 480)))
        let pointerScreen = try XCTUnwrap(
            NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        )

        panel.positionOnActiveScreen()

        let expectedFrame = HistoryPanelWindow.topCenteredFrame(
            panelSize: panel.frame.size,
            screenFrame: pointerScreen.visibleFrame,
            topInset: HistoryPanelWindow.defaultTopInset
        )
        XCTAssertEqual(panel.frame, expectedFrame)
    }

    func testResignKey_shouldHideVisiblePanel() async {
        let panel = HistoryPanelWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 480))
        panel.orderFront(nil)
        XCTAssertTrue(panel.isVisible)

        panel.resignKey()
        await Task.yield()

        XCTAssertFalse(panel.isVisible)
    }

    func testShouldHideAfterResigningKey_whenDetailSheetIsAttached_shouldKeepPanelVisible() {
        XCTAssertFalse(
            HistoryPanelWindow.shouldHideAfterResigningKey(
                hasAttachedSheet: true,
                isKeyWindow: false
            )
        )
    }

    func testShouldHideAfterResigningKey_whenPanelRegainsKey_shouldKeepPanelVisible() {
        XCTAssertFalse(
            HistoryPanelWindow.shouldHideAfterResigningKey(
                hasAttachedSheet: false,
                isKeyWindow: true
            )
        )
    }

    func testShouldHideAfterResigningKey_whenFocusMovesOutsidePanel_shouldHidePanel() {
        XCTAssertTrue(
            HistoryPanelWindow.shouldHideAfterResigningKey(
                hasAttachedSheet: false,
                isKeyWindow: false
            )
        )
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
