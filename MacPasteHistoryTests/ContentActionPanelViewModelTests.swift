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

    func testOCRImageRunsTextActionAgainstRecognizedText() async {
        let viewModel = ContentActionPanelViewModel()
        let item = makeImageItem(filePath: "/tmp/not-used.png", detectedType: .json, ocrText: "{\"name\":\"粘易\"}")
        viewModel.present(for: item, sourceText: item.ocrText, recommendedOnly: true)

        viewModel.execute(actionID: ContentActionID(rawValue: "json.format"))

        XCTAssertEqual(viewModel.state, .previewing)
        XCTAssertTrue(viewModel.editedOutput.contains("\"name\" : \"粘易\""))
    }

    func testRawImageOnlyOffersApplicableBinaryActions() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeImageItem(filePath: "/tmp/image.png"))

        XCTAssertEqual(viewModel.allActions.map(\.id.rawValue), ["base64.encode"])
    }

    func testAllActionsPutRecommendedActionsFirstAndFilterByLocalizedTitle() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeItem(text: "{\"a\":1}", detectedType: .json))

        XCTAssertEqual(Array(viewModel.allActions.prefix(5)).map(\.id.rawValue), [
            "json.escape", "json.format", "json.minify", "json.unescape", "json.validate"
        ])
        viewModel.commandSearchText = L10n.string("json.format")
        XCTAssertEqual(viewModel.availableActions.map(\.id.rawValue), ["json.format"])
    }

    func testFailureExposesMessageAndDoesNotExposeSuccessfulOutput() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeItem(text: "bad%2"))

        viewModel.execute(actionID: ContentActionID(rawValue: "url.decode"))

        XCTAssertEqual(viewModel.failureMessageKey, "content-action.url.invalid")
        XCTAssertFalse(viewModel.hasUsableResult)
    }

    private func makeItem(text: String, detectedType: DetectedContentType? = nil) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 1, contentType: .text, textContent: text, filePath: nil, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "hash", textLength: text.count, fileSize: nil, imageWidth: nil, imageHeight: nil, imageFormat: nil, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast, detectedType: detectedType)
    }

    private func makeImageItem(filePath: String, detectedType: DetectedContentType? = nil, ocrText: String? = nil) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 2, contentType: .image, textContent: "", filePath: filePath, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "image-hash", textLength: 0, fileSize: nil, imageWidth: 1, imageHeight: 1, imageFormat: .png, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast, detectedType: detectedType, ocrText: ocrText)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 where condition() == false {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
