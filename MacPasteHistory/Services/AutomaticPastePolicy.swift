import Foundation

enum AutomaticPasteReadiness: Equatable {
    case clipboardOnly
    case permissionRequired
    case ready
}

struct AutomaticPastePolicy {
    private let config: UserDefaultsConfig
    private let accessibilityPermissionService: any AccessibilityPermissionServing

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        accessibilityPermissionService: any AccessibilityPermissionServing = AccessibilityPermissionService()
    ) {
        self.config = config
        self.accessibilityPermissionService = accessibilityPermissionService
    }

    var readiness: AutomaticPasteReadiness {
        guard config.automaticPasteEnabled else {
            return .clipboardOnly
        }
        return accessibilityPermissionService.hasAccessibilityPermission ? .ready : .permissionRequired
    }
}
