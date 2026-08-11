import Foundation

struct AppVersionInfo: Equatable {
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
