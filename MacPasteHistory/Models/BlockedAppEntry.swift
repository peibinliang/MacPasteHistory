import Foundation

struct BlockedAppEntry: Codable, Equatable, Identifiable {
    var id: String { bundleID }

    let bundleID: String
    var displayName: String
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        bundleID: String,
        displayName: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func isValidBundleID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("."), trimmed.count <= 255 else {
            return false
        }
        return trimmed.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$"#, options: .regularExpression) != nil
    }
}
