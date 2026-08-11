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
            "content-type.jwt", "content-type.timestamp", "content-type.sql", "content-type.shell", "Space", "Return",
            "Filter sensitive content", "Disable Sensitive Content Filtering?",
            "Detected passwords, tokens, identity numbers, and payment card numbers may be stored in the local unencrypted history database.",
            "Keep Filtering", "Disable Filtering",
            "When enabled, detected passwords, tokens, identity numbers, and payment card numbers are not saved.",
            "About & Updates", "Version information and software updates", "Version %@ (Build %@)", "View on GitHub",
            "Automatically check for updates", "Check for Updates…", "Checking for updates…",
            "You're up to date.", "Update %@ is available.", "Update check failed: %@",
            "Automatic Paste", "When disabled, selected content is copied and you can paste it manually.",
            "Accessibility permission is required for Automatic Paste.", "Copied. Press Command-V to paste manually.",
            "ai.action.polish", "ai.polishing.progress", "ai.consent.title", "ai.consent.message", "ai.consent.continue",
            "ai.error.missing-api-key", "ai.error.authentication", "ai.error.rate-limited", "ai.error.offline",
            "ai.error.timeout", "ai.error.response-too-large", "ai.error.empty-result", "ai.error.invalid-input",
            "ai.error.service-unavailable", "ai.usage.persistence-failed", "ai.usage.request-summary", "ai.usage.unavailable",
            "ai.settings.title", "ai.settings.subtitle", "ai.settings.configuration", "ai.settings.remote-processing-note",
            "ai.settings.model", "ai.settings.api-key-placeholder", "ai.settings.save-key", "ai.settings.replace-key",
            "ai.settings.key-stored", "ai.settings.key-saved", "ai.settings.key-save-failed", "ai.settings.key-removed",
            "ai.settings.key-remove-failed", "ai.settings.key-status-failed", "ai.settings.remove-key-title",
            "ai.settings.remove-key-message", "ai.settings.token-usage", "ai.settings.provider-reported",
            "ai.settings.current-model", "ai.settings.all-models", "ai.settings.token-summary"
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
