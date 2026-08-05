import Foundation

struct CaptureSourceIdentity {
    let key: String
    let appName: String?
    let bundleID: String?

    init(appName: String?, bundleID: String?) {
        let normalizedAppName = Self.trimmedValue(appName)
        let normalizedBundleID = Self.trimmedValue(bundleID)

        self.appName = normalizedAppName
        self.bundleID = normalizedBundleID
        if let normalizedBundleID {
            key = "bundle:\(normalizedBundleID.lowercased())"
        } else if let normalizedAppName {
            key = "app:\(normalizedAppName.lowercased())"
        } else {
            key = "unknown"
        }
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
