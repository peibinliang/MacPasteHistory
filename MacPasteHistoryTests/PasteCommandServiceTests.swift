import XCTest
@testable import MacPasteHistory

final class PasteCommandServiceTests: XCTestCase {
    func testSendPasteCommand_shouldDispatchCommandVPaste() {
        let sender = FakePasteCommandSender()
        let service = PasteCommandService(sender: sender)

        service.sendPasteCommand()

        XCTAssertEqual(sender.sendCommandVPasteCallCount, 1)
    }
}

private final class FakePasteCommandSender: PasteCommandSending {
    private(set) var sendCommandVPasteCallCount = 0

    func sendCommandVPaste() {
        sendCommandVPasteCallCount += 1
    }
}
