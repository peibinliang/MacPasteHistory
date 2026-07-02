import Foundation

/// Handles privacy controls: pause recording, blocked apps, and sensitive content filtering.
struct PrivacyService {
    private var isPaused = false
    private var blockedBundleIDs: Set<String> = []
    private let filterSensitiveContent: Bool

    init(filterSensitiveContent: Bool = true) {
        self.filterSensitiveContent = filterSensitiveContent
    }

    // MARK: - Pause

    mutating func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    var recordingPaused: Bool {
        isPaused
    }

    // MARK: - Blocked Apps

    mutating func blockApp(bundleID: String) {
        blockedBundleIDs.insert(bundleID)
    }

    mutating func unblockApp(bundleID: String) {
        blockedBundleIDs.remove(bundleID)
    }

    mutating func setBlockedApps(_ bundleIDs: Set<String>) {
        blockedBundleIDs = bundleIDs
    }

    func isAppBlocked(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return blockedBundleIDs.contains(bundleID)
    }

    var blockedApps: Set<String> {
        blockedBundleIDs
    }

    // MARK: - Sensitive Content Detection

    /// Returns true if the text appears to contain sensitive information that should not be persisted.
    func isSensitiveContent(_ text: String) -> Bool {
        guard filterSensitiveContent else { return false }
        return SensitiveContentDetector.isSensitive(text)
    }
}

// MARK: - Sensitive Content Detection

enum SensitiveContentDetector {
    /// Patterns that indicate sensitive content (passwords, tokens, IDs, bank cards).
    private static let patterns: [String] = [
        #"(?i)(password|passwd|pwd)\s*[:=]\s*\S+"#,                    // password assignments
        #"(?i)(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*\S+"#, // API keys/tokens
        #"\b\d{16,19}\b"#,                                              // 16-19 digit numbers (bank cards)
        #"\b\d{15}(\d{2}[\dX])?\b"#,                                   // Chinese ID-like numbers
        #"(?i)(bearer|basic)\s+[A-Za-z0-9+/=]{20,}"#,                 // Auth headers
        #"\b[A-Za-z0-9]{32,64}\b"#,                                    // Long hex tokens
    ]

    static func isSensitive(_ text: String) -> Bool {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }
}
