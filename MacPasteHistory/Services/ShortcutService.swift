import AppKit
import Carbon
import Foundation

enum ShortcutRegistrationState: Equatable {
    case unregistered
    case registered(ShortcutConfiguration)
    case invalid(ShortcutConfiguration)
    case conflict(ShortcutConfiguration, OSStatus)
}

protocol ShortcutRegistrationManaging: AnyObject {
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus
    func unregister()
}

/// Handles registration and listening for a global keyboard shortcut.
final class ShortcutService {
    private let logger = Logger(category: "ShortcutService")
    private var config: UserDefaultsConfig
    private let registrationManager: ShortcutRegistrationManaging
    private(set) var registrationState: ShortcutRegistrationState = .unregistered

    var usesSystemRegistration: Bool {
        registrationManager is CarbonShortcutRegistrationManager
    }

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        registrationManager: ShortcutRegistrationManaging = CarbonShortcutRegistrationManager()
    ) {
        self.config = config
        self.registrationManager = registrationManager
    }

    // MARK: - Public API

    @discardableResult
    func registerConfiguredShortcut() -> ShortcutRegistrationState {
        register(configuration: config.shortcutConfiguration, persistOnSuccess: false)
    }

    @discardableResult
    func registerDefaultShortcut() -> ShortcutRegistrationState {
        register(configuration: .default)
    }

    @discardableResult
    func resetToDefaultShortcut() -> ShortcutRegistrationState {
        register(configuration: .default)
    }

    @discardableResult
    func register(configuration: ShortcutConfiguration) -> ShortcutRegistrationState {
        register(configuration: configuration, persistOnSuccess: true)
    }

    func unregister() {
        registrationManager.unregister()
        registrationState = .unregistered
    }

    private func register(configuration: ShortcutConfiguration, persistOnSuccess: Bool) -> ShortcutRegistrationState {
        guard configuration.isValid else {
            registrationState = .invalid(configuration)
            return registrationState
        }

        let previousConfiguration: ShortcutConfiguration?
        if case .registered(let registeredConfiguration) = registrationState {
            previousConfiguration = registeredConfiguration
        } else {
            previousConfiguration = nil
        }

        let status = registrationManager.register(
            keyCode: configuration.keyCode,
            modifiers: configuration.modifiers
        )

        guard status == noErr else {
            logger.error("Failed to register global hot key: \(status)")
            if let previousConfiguration {
                _ = registrationManager.register(
                    keyCode: previousConfiguration.keyCode,
                    modifiers: previousConfiguration.modifiers
                )
                registrationState = .registered(previousConfiguration)
            } else {
                registrationState = .conflict(configuration, status)
            }
            return registrationState
        }

        if persistOnSuccess {
            config.shortcutConfiguration = configuration
        }
        registrationState = .registered(configuration)
        logger.info("Global shortcut registered: \(configuration.displayLabel)")
        return registrationState
    }

    deinit {
        unregister()
    }
}

final class IsolatedQAShortcutRegistrationManager: ShortcutRegistrationManaging {
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus { noErr }
    func unregister() {}
}

final class CarbonShortcutRegistrationManager: ShortcutRegistrationManaging {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private struct HotKeyID {
        static let showHistory = EventHotKeyID(signature: 0x50415354, id: 1) // 'PAST'
    }

    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, _ -> OSStatus in
                guard let eventRef else { return OSStatus(eventNotHandledErr) }
                var receivedID = EventHotKeyID()
                let result = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )
                guard result == noErr else { return OSStatus(eventNotHandledErr) }

                if receivedID.id == HotKeyID.showHistory.id {
                    NotificationCenter.default.post(name: .globalShortcutPressed, object: nil)
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard handlerStatus == noErr else {
            unregister()
            return handlerStatus
        }

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            HotKeyID.showHistory,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            unregister()
        }
        return status
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}

extension Notification.Name {
    static let globalShortcutPressed = Notification.Name("globalShortcutPressed")
}
