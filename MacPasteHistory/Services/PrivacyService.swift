import Foundation

/// Handles privacy controls: pause recording, blocked apps, and sensitive content filtering.
struct PrivacyService {
    private var config: UserDefaultsConfig

    init(config: UserDefaultsConfig = UserDefaultsConfig()) {
        self.config = config
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
        guard config.filterSensitiveContent else { return false }
        return SensitiveContentDetector.detect(text).shouldBlockPersistence
    }
}
