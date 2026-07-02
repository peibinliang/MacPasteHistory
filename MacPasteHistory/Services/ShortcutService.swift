import AppKit
import Carbon
import Foundation

/// Handles registration and listening for a global keyboard shortcut.
/// Defaults to Command + Shift + V.
final class ShortcutService {
    private let logger = Logger(category: "ShortcutService")
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let config = UserDefaultsConfig()

    var onShortcutPressed: (() -> Void)?

    private struct HotKeyID {
        static let showHistory = EventHotKeyID(signature: 0x50415354, id: 1) // 'PAST'
    }

    // MARK: - Public API

    func registerDefaultShortcut() {
        let keyCode = UInt32(kVK_ANSI_V)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        register(keyCode: keyCode, modifiers: modifiers)
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        let hotKeyID = HotKeyID.showHistory

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
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

        guard status == noErr else {
            logger.error("Failed to install event handler: \(status)")
            return
        }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus == noErr {
            logger.info("Global shortcut registered: keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            logger.error("Failed to register global hot key: \(registerStatus)")
            unregister()
        }
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
