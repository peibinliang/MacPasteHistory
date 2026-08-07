import XCTest
@testable import MacPasteHistory

final class LocalizationCoverageTests: XCTestCase {
    func testEnhancedFeatureKeys_existInEverySupportedLocalization() throws {
        let requiredKeys = [
            "Automatic", "Recommended Actions", "All Actions", "Search actions", "Copy Result", "Paste Result", "Save as New Record", "Restore Result",
            "Actions", "All Actions…", "Back", "Origin", "Original", "Result", "Save", "Steps", "Recognize Text", "Remove search token",
            "Existing clipboard record was reused.", "Failed to record clipboard usage.", "Failed to save derived clipboard content.",
            "Failed to update clipboard content type.", "Paste was not sent. Press Command-V to paste manually.",
            "Source record deleted", "Derived content", "Recognizing text", "Retry", "content-action.jwt.signature-not-verified",
            "content-action.jwt.expired", "content-action.jwt.not-expired", "content-action.jwt.no-expiration",
            "content-action.timestamp.invalid", "content-action.base64.invalid", "jwt.inspect", "timestamp.convert", "imageMissing", "visionFailed", "Execute selected content action", "Edited result", "Recognized text", "Text recognition failed",
            "url.encode-query-value", "url.decode", "url.extract-host", "url.parse-query", "sql.single-line", "shell.quote-argument",
            "header", "payload", "summary", "local", "utc", "iso8601", "seconds", "milliseconds", "Unsupported for this content",
            "content-type.plain-text", "content-type.image", "content-type.json", "content-type.url", "content-type.base64",
            "content-type.jwt", "content-type.timestamp", "content-type.sql", "content-type.shell", "Space", "Return"
        ]
        let localizations = ["en", "zh-Hans", "zh-Hant"]

        for localization in localizations {
            let values = try strings(for: localization)
            XCTAssertTrue(Set(requiredKeys).isSubset(of: Set(values.keys)), "Missing enhanced feature key in \(localization)")
            XCTAssertFalse(requiredKeys.contains { values[$0]?.isEmpty ?? true }, "Empty enhanced feature value in \(localization)")
        }
    }

    func testEveryRegisteredActionAndDetectedTypeHasLocalizedTitles() throws {
        let actionKeys = ContentActionRegistry().actions.map(\.titleKey)
        let typeKeys = DetectedContentType.allCases.map(\.localizationKey)

        for localization in ["en", "zh-Hans", "zh-Hant"] {
            let values = try strings(for: localization)
            XCTAssertTrue(Set(actionKeys + typeKeys).isSubset(of: Set(values.keys)))
        }
    }

    private func strings(for language: String) throws -> [String: String] {
        let repositoryURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = repositoryURL.appendingPathComponent("MacPasteHistory/Resources/\(language).lproj/Localizable.strings")
        guard let values = NSDictionary(contentsOf: url) as? [String: String] else {
            throw NSError(domain: "LocalizationCoverageTests", code: 1)
        }
        return values
    }
}
