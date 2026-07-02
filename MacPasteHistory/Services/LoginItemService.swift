import Foundation
import ServiceManagement

protocol LoginItemManaging {
    func register() throws
    func unregister() throws
}

struct SystemLoginItemManager: LoginItemManaging {
    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

final class LoginItemService {
    private let manager: LoginItemManaging
    private var config: UserDefaultsConfig

    init(manager: LoginItemManaging = SystemLoginItemManager(), config: UserDefaultsConfig = UserDefaultsConfig()) {
        self.manager = manager
        self.config = config
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try manager.register()
        } else {
            try manager.unregister()
        }

        config.launchAtStartup = isEnabled
    }
}
