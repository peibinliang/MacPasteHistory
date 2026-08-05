import XCTest
@testable import MacPasteHistory

final class LocalizationCoverageTests: XCTestCase {
    func testEnhancedFeatureKeys_existInEverySupportedLocalization() throws {
        let requiredKeys = [
            "Automatic", "Recommended Actions", "All Actions", "Search actions", "Copy Result", "Paste Result", "Save as New Record", "Restore Result",
            "Source record deleted", "Derived content", "Recognizing text", "Retry", "content-action.jwt.signature-not-verified",
            "content-action.timestamp.invalid", "content-action.base64.invalid", "jwt.inspect", "timestamp.convert", "imageMissing", "visionFailed", "Execute selected content action", "Edited result", "Recognized text", "Text recognition failed"
        ]
        let localizations = ["en", "zh-Hans", "zh-Hant"]

        for localization in localizations {
            let values = try strings(for: localization)
            XCTAssertTrue(Set(requiredKeys).isSubset(of: Set(values.keys)), "Missing enhanced feature key in \(localization)")
            XCTAssertFalse(requiredKeys.contains { values[$0]?.isEmpty ?? true }, "Empty enhanced feature value in \(localization)")
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
