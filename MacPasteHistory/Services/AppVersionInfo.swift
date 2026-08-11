import Foundation

protocol AppVersionProviding {
    var displayName: String { get }
    var shortVersion: String { get }
    var buildNumber: String { get }
    var localizedVersionText: String { get }
}

struct AppVersionInfo: AppVersionProviding, Equatable {
    let displayName: String
    let shortVersion: String
    let buildNumber: String

    var localizedVersionText: String {
        String(
            format: L10n.string("Version %@ (Build %@)"),
            shortVersion,
            buildNumber
        )
    }

    init(infoDictionary: [String: Any]) {
        displayName = infoDictionary["CFBundleDisplayName"] as? String ?? AppBrand.displayName
        shortVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "—"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "—"
    }

    static var current: AppVersionInfo {
        AppVersionInfo(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }
}
