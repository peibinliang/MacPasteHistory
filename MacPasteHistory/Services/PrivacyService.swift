import Foundation

/// Handles privacy controls: pause recording, blocked apps, and sensitive content filtering.
struct PrivacyService {
    private var config: UserDefaultsConfig
    private let filterSensitiveContent: Bool

    init(config: UserDefaultsConfig = UserDefaultsConfig(), filterSensitiveContent: Bool = true) {
        self.config = config
        self.filterSensitiveContent = filterSensitiveContent
    }

    // MARK: - Pause

    mutating func setPaused(_ paused: Bool) {
        config.recordingPaused = paused
    }

    var recordingPaused: Bool {
        config.recordingPaused
    }

    // MARK: - Blocked Apps

    mutating func blockApp(bundleID: String) {
        guard BlockedAppEntry.isValidBundleID(bundleID) else { return }
        var entries = config.blockedApps
        if let index = entries.firstIndex(where: { $0.bundleID == bundleID }) {
            entries[index].isEnabled = true
            entries[index].updatedAt = Date()
        } else {
            entries.append(BlockedAppEntry(bundleID: bundleID, displayName: bundleID))
        }
        config.blockedApps = entries
    }

    mutating func unblockApp(bundleID: String) {
        config.blockedApps = config.blockedApps.filter { $0.bundleID != bundleID }
    }

    mutating func setBlockedApps(_ bundleIDs: Set<String>) {
        config.blockedApps = bundleIDs
            .filter(BlockedAppEntry.isValidBundleID)
            .sorted()
            .map { BlockedAppEntry(bundleID: $0, displayName: $0) }
    }

    func isAppBlocked(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return config.blockedApps.contains { $0.bundleID == bundleID && $0.isEnabled }
    }

    var blockedApps: Set<String> {
        Set(config.blockedApps.filter(\.isEnabled).map(\.bundleID))
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
