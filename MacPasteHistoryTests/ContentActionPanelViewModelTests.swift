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
        viewModel.commandSearchText = "json"

        viewModel.close()

        XCTAssertEqual(viewModel.state, .closed)
        XCTAssertNil(viewModel.session)
        XCTAssertEqual(viewModel.editedOutput, "")
        XCTAssertEqual(viewModel.commandSearchText, "")
    }

    func testPresent_clearsSearchFromPreviousPresentation() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeItem(text: "hello"))
        viewModel.commandSearchText = "base64"

        viewModel.present(for: makeItem(text: "world"))

        XCTAssertEqual(viewModel.commandSearchText, "")
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

    func testPlainTextOnlyOffersGenericTextAndEncodingActions() {
        let viewModel = ContentActionPanelViewModel()
        viewModel.present(for: makeItem(text: "Hello 粘易"))

        XCTAssertEqual(Set(viewModel.availableActions.map(\.id.rawValue)), Set([
            "text.trim", "text.remove-empty-lines", "text.deduplicate-lines", "text.single-line",
            "text.uppercase", "text.lowercase", "text.markdown-code-block", "json.escape",
            "url.encode-query-value", "base64.encode", "shell.quote-argument"
        ]))
        XCTAssertFalse(viewModel.availableActions.contains { $0.id.rawValue == "json.format" })
        XCTAssertFalse(viewModel.availableActions.contains { $0.id.rawValue == "base64.decode" })
    }

    func testStructuredTextIsClassifiedOnPresentationAndOnlyOffersMatchingActions() {
        let cases: [(String, DetectedContentType, Set<String>)] = [
            ("{\"name\":\"粘易\"}", .json, ["json.format", "json.minify", "json.validate", "json.escape", "json.unescape"]),
            ("https://example.com/path?a=1", .url, ["url.encode-query-value", "url.decode", "url.extract-host", "url.parse-query"]),
            ("SGVsbG8gd29ybGQ=", .base64, ["base64.encode", "base64.decode", "base64.decode-url-safe", "base64.validate"]),
            ("5Lit5paH", .base64, ["base64.encode", "base64.decode", "base64.decode-url-safe", "base64.validate"]),
            ("1700000000", .timestamp, ["timestamp.convert"]),
            ("SELECT id FROM users WHERE active = 1", .sql, ["sql.single-line"]),
            ("git log --oneline | head -5", .shell, ["shell.quote-argument"])
        ]

        for (text, expectedType, expectedActions) in cases {
            let viewModel = ContentActionPanelViewModel()
            viewModel.present(for: makeItem(text: text))

            XCTAssertEqual(viewModel.activeContentType, expectedType, "Failed to classify \(text)")
            XCTAssertEqual(Set(viewModel.availableActions.map(\.id.rawValue)), expectedActions)
        }
    }

    func testImageWithOCRUsesRecognizedTextClassificationWithoutImageOnlyActions() {
        let viewModel = ContentActionPanelViewModel()
        let item = makeImageItem(filePath: "/tmp/image.png", ocrText: "{\"name\":\"粘易\"}")

        viewModel.present(for: item, sourceText: item.ocrText)

        XCTAssertEqual(viewModel.activeContentType, .json)
        XCTAssertEqual(Set(viewModel.availableActions.map(\.id.rawValue)), Set([
            "json.format", "json.minify", "json.validate", "json.escape", "json.unescape"
        ]))
        XCTAssertFalse(viewModel.availableActions.contains { $0.id.rawValue == "base64.encode" })
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

    func testMoveBack_restoresPresentationMetadataFromTheCurrentStep() {
        let firstID = ContentActionID(rawValue: "test.first-metadata")
        let secondID = ContentActionID(rawValue: "test.second-metadata")
        let firstUsage = DeepSeekTokenUsage(inputTokens: 8, outputTokens: 3, totalTokens: 11, cachedInputTokens: 2)
        let firstVariant = ContentActionCopyVariant(id: "first", titleKey: "first", value: "first variant")
        let firstNotice = ContentActionNotice(messageKey: "first.notice")
        let registry = ContentActionRegistry(actions: [
            MetadataContentAction(
                id: firstID,
                result: ContentActionResult(
                    output: "first output",
                    syntax: .plainText,
                    notices: [firstNotice],
                    copyVariants: [firstVariant],
                    aiTokenUsage: firstUsage
                )
            ),
            MetadataContentAction(
                id: secondID,
                result: ContentActionResult(
                    output: "second output",
                    syntax: .plainText,
                    notices: [],
                    copyVariants: [],
                    isAIUsageUnavailable: true
                )
            )
        ])
        let viewModel = ContentActionPanelViewModel(registry: registry)
        viewModel.present(for: makeItem(text: "source"))
        viewModel.execute(actionID: firstID)
        viewModel.execute(actionID: secondID)

        viewModel.moveBack()

        XCTAssertEqual(viewModel.selectedAction, firstID)
        XCTAssertEqual(viewModel.copyVariants, [firstVariant])
        XCTAssertEqual(viewModel.notices, [firstNotice])
        XCTAssertEqual(viewModel.aiTokenUsage, firstUsage)
        XCTAssertFalse(viewModel.isAIUsageUnavailable)
        XCTAssertEqual(viewModel.editedOutput, "first output")
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

private struct MetadataContentAction: ContentAction {
    let id: ContentActionID
    let result: ContentActionResult
    let titleKey = "test.metadata"
    let category = ContentActionCategory.text
    let supportedTypes: Set<DetectedContentType> = [.plainText]

    func validate(input: String) -> ActionValidationResult { .valid }
    func execute(input: String) throws -> ContentActionResult { result }
}
