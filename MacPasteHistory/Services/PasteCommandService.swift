import AppKit
import ApplicationServices
import Carbon
import Foundation

enum PasteActivationPolicy {
    static let options: NSApplication.ActivationOptions = [.activateIgnoringOtherApps]
}

enum PasteTargetPolicy {
    static func preferredBundleIdentifier(
        frontmostBundleIdentifier: String?,
        lastExternalBundleIdentifier: String?,
        ownBundleIdentifier: String?
    ) -> String? {
        if let frontmostBundleIdentifier,
           frontmostBundleIdentifier != ownBundleIdentifier {
            return frontmostBundleIdentifier
        }

        guard lastExternalBundleIdentifier != ownBundleIdentifier else {
            return nil
        }
        return lastExternalBundleIdentifier
    }
}

protocol PasteCommandSending {
    func sendCommandVPaste() -> Bool
}

final class PasteCommandService {
    private let sender: PasteCommandSending

    init(sender: PasteCommandSending = SystemPasteCommandSender()) {
        self.sender = sender
    }

    func sendPasteCommand() -> Bool {
        sender.sendCommandVPaste()
    }
}

private final class SystemPasteCommandSender: PasteCommandSending {
    func sendCommandVPaste() -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }

        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
