import AppKit
import Foundation

enum AppPreferencesApplyResult: Equatable {
    case applied
    case restartRequired
}

@MainActor
final class AppPreferencesService {
    private var config: UserDefaultsConfig
    private let applyActivationPolicy: (NSApplication.ActivationPolicy) -> Bool

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        applyActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Bool = { NSApp.setActivationPolicy($0) }
    ) {
        self.config = config
        self.applyActivationPolicy = applyActivationPolicy
    }

    @discardableResult
    func applyDockIconPreference() -> AppPreferencesApplyResult {
        applyDockIconVisibility(config.showDockIcon)
    }

    @discardableResult
    func setDockIconVisible(_ isVisible: Bool) -> AppPreferencesApplyResult {
        config.showDockIcon = isVisible
        return applyDockIconVisibility(isVisible)
    }

    private func applyDockIconVisibility(_ isVisible: Bool) -> AppPreferencesApplyResult {
        let policy: NSApplication.ActivationPolicy = isVisible ? .regular : .accessory
        return applyActivationPolicy(policy) ? .applied : .restartRequired
    }
}
