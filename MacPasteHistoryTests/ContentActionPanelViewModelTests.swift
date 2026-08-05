import XCTest
@testable import MacPasteHistory

@MainActor
final class ContentActionPanelViewModelTests: XCTestCase {
    func testExecute_usesEditedSessionOutputAndPublishesPreview() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeItem(text: "hello"))

        viewModel.execute(actionID: ContentActionID(rawValue: "text.uppercase"))
        viewModel.updateEditedOutput("custom")
        viewModel.execute(actionID: ContentActionID(rawValue: "text.markdown-code-block"))

        XCTAssertEqual(viewModel.state, .previewing)
        XCTAssertEqual(viewModel.session?.steps.map(\.input), ["hello", "custom"])
        XCTAssertEqual(viewModel.editedOutput, "```\ncustom\n```")
        XCTAssertEqual(viewModel.selectedAction?.rawValue, "text.markdown-code-block")
    }

    func testClose_clearsActiveSession() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeItem(text: "hello"))

        viewModel.close()

        XCTAssertEqual(viewModel.state, .closed)
        XCTAssertNil(viewModel.session)
        XCTAssertEqual(viewModel.editedOutput, "")
    }

    private func makeItem(text: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 1, contentType: .text, textContent: text, filePath: nil, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "hash", textLength: text.count, fileSize: nil, imageWidth: nil, imageHeight: nil, imageFormat: nil, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast)
    }
}
