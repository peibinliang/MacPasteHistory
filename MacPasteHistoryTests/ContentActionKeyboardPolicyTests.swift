import XCTest
@testable import MacPasteHistory

final class ContentActionKeyboardPolicyTests: XCTestCase {
    private let actions = [ContentActionID(rawValue: "first"), ContentActionID(rawValue: "second"), ContentActionID(rawValue: "third")]

    func testMoveSelection_wrapsAtBothEnds() {
        XCTAssertEqual(ContentActionKeyboardPolicy.moveSelection(current: nil, actions: actions, direction: .down), actions[0])
        XCTAssertEqual(ContentActionKeyboardPolicy.moveSelection(current: actions[0], actions: actions, direction: .up), actions[2])
        XCTAssertEqual(ContentActionKeyboardPolicy.moveSelection(current: actions[2], actions: actions, direction: .down), actions[0])
    }

    func testEscapeTarget_closesPaletteThenPreview() {
        XCTAssertEqual(ContentActionKeyboardPolicy.escapeTarget(for: .choosing), .closePalette)
        XCTAssertEqual(ContentActionKeyboardPolicy.escapeTarget(for: .previewing), .closePreview)
        XCTAssertEqual(ContentActionKeyboardPolicy.escapeTarget(for: .closed), .closePanel)
    }
}
