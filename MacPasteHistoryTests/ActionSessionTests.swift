import XCTest
@testable import MacPasteHistory

final class ActionSessionTests: XCTestCase {
    func testSession_usesSourceThenCurrentEditedOutputAndDropsAbandonedBranch() {
        let source = makeItem(text: "original")
        let first = TestContentAction(id: "first", titleKey: "action.first")
        let second = TestContentAction(id: "second", titleKey: "action.second")
        let replacement = TestContentAction(id: "replacement", titleKey: "action.replacement")
        var session = ActionSession(sourceItem: source)

        session.append(action: first, result: result("one"), input: source.textContent)
        session.updateEditedOutput("one edited")
        session.append(action: second, result: result("two"), input: session.currentOutput)
        session.moveBack()
        session.append(action: replacement, result: result("replacement"), input: session.currentOutput)

        XCTAssertEqual(session.steps.map(\.input), ["original", "one edited"])
        XCTAssertEqual(session.steps.map(\.actionID.rawValue), ["first", "replacement"])
        XCTAssertEqual(session.currentOutput, "replacement")
        XCTAssertEqual(session.actionSummary, "action.first → action.replacement")
    }

    func testLocalizedActionSummaryUsesSelectedLanguageWithoutChangingStableSummary() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.zhHans.rawValue, forKey: LanguageManager.preferredLanguageKey)
        let source = makeItem(text: "original")
        var session = ActionSession(sourceItem: source)
        let decode = Base64ContentAction(kind: .decode)
        let format = JSONContentAction(kind: .format)
        session.append(action: decode, result: result("{}"), input: "e30=")
        session.append(action: format, result: result("{}"), input: "{}")

        XCTAssertEqual(session.actionSummary, "base64.decode → json.format")
        XCTAssertEqual(session.localizedActionSummary(defaults: defaults), "解码 Base64 → 格式化 JSON")
    }

    func testSession_restoreMoveBackAndClear_affectOnlyCurrentState() {
        let source = makeItem(text: "original")
        let first = TestContentAction(id: "first", titleKey: "action.first")
        let second = TestContentAction(id: "second", titleKey: "action.second")
        var session = ActionSession(sourceItem: source)
        session.append(action: first, result: result("one"), input: "original")
        session.updateEditedOutput("one edited")
        session.restoreCurrentOutput()
        XCTAssertEqual(session.currentOutput, "one")

        session.append(action: second, result: result("two"), input: session.currentOutput)
        session.updateEditedOutput("two edited")
        session.moveBack()
        XCTAssertEqual(session.currentOutput, "one")
        XCTAssertEqual(session.steps[1].editedOutput, "two edited")

        session.clear()
        XCTAssertTrue(session.steps.isEmpty)
        XCTAssertNil(session.currentIndex)
        XCTAssertEqual(session.currentOutput, "original")
    }

    func testSession_currentMetadataTracksVisibleStepAfterMovingBack() {
        let source = makeItem(text: "original")
        let first = TestContentAction(id: "first", titleKey: "action.first")
        let second = TestContentAction(id: "second", titleKey: "action.second")
        var session = ActionSession(sourceItem: source)
        session.append(action: first, result: result("one"), input: "original")
        session.append(action: second, result: result("two"), input: "one")

        session.moveBack()

        XCTAssertEqual(session.currentStep?.actionID, first.id)
        XCTAssertEqual(session.currentActionSummary, "action.first")
        XCTAssertEqual(session.actionSummary, "action.first")
    }

    private func result(_ output: String) -> ContentActionResult {
        ContentActionResult(output: output, syntax: .plainText, notices: [], copyVariants: [])
    }

    private func makeItem(text: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 1, contentType: .text, textContent: text, filePath: nil, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "source-hash", textLength: text.count, fileSize: nil, imageWidth: nil, imageHeight: nil, imageFormat: nil, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast)
    }

}

private struct TestContentAction: ContentAction {
    let id: ContentActionID
    let titleKey: String
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.plainText]

    init(id: String, titleKey: String) {
        self.id = ContentActionID(rawValue: id)
        self.titleKey = titleKey
    }

    func validate(input: String) -> ActionValidationResult { .valid }
    func execute(input: String) throws -> ContentActionResult { ContentActionResult(output: input, syntax: .plainText, notices: [], copyVariants: []) }
}
