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

    func testImageBase64Encoding_readsOriginalFileDataAndPublishesPreview() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try imageData.write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeImageItem(filePath: imageURL.path), recommendedOnly: true)

        XCTAssertTrue(viewModel.recommendedActions.contains { $0.id.rawValue == "base64.encode" })

        viewModel.execute(actionID: ContentActionID(rawValue: "base64.encode"))
        await waitUntil { viewModel.state == .previewing }

        XCTAssertEqual(viewModel.editedOutput, imageData.base64EncodedString())
    }

    func testImageBase64Encoding_whenOriginalFileIsMissingPublishesFailure() async {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeImageItem(filePath: "/tmp/missing-base64-image.png"), recommendedOnly: true)

        viewModel.execute(actionID: ContentActionID(rawValue: "base64.encode"))
        await waitUntil {
            viewModel.state == .failed(.invalidInput(messageKey: "imageMissing"))
        }

        XCTAssertEqual(viewModel.state, .failed(.invalidInput(messageKey: "imageMissing")))
    }

    private func makeItem(text: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 1, contentType: .text, textContent: text, filePath: nil, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "hash", textLength: text.count, fileSize: nil, imageWidth: nil, imageHeight: nil, imageFormat: nil, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast)
    }

    private func makeImageItem(filePath: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 2, contentType: .image, textContent: "", filePath: filePath, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "image-hash", textLength: 0, fileSize: nil, imageWidth: 1, imageHeight: 1, imageFormat: .png, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 where condition() == false {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
