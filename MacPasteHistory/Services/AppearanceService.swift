import AppKit

@MainActor
final class AppearanceService {
    private var config: UserDefaultsConfig
    private let applyAppearance: (AppAppearance) -> Void

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        applyAppearance: @escaping (AppAppearance) -> Void = { appearance in
            switch appearance {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    ) {
        self.config = config
        self.applyAppearance = applyAppearance
    }

    func applyCurrentAppearance() {
        applyAppearance(config.appAppearance)
    }

    func setAppearance(_ appearance: AppAppearance) {
        config.appAppearance = appearance
        applyAppearance(appearance)
    }
}
