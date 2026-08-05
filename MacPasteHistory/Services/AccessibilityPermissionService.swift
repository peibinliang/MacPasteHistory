import AppKit
import ApplicationServices
import Foundation

enum AccessibilityPermissionReminderTrigger {
    case launch
    case automaticPaste
}

protocol AccessibilityPermissionChecking {
    func isProcessTrusted() -> Bool
}

protocol AccessibilitySettingsOpening: AnyObject {
    func open(_ url: URL)
}

final class AccessibilityPermissionService {
    static let systemSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    private let permissionChecker: AccessibilityPermissionChecking
    private let settingsOpener: AccessibilitySettingsOpening
    private var didRemindOnLaunch = false
    private var didRemindForAutomaticPaste = false

    init(
        permissionChecker: AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
        settingsOpener: AccessibilitySettingsOpening = SystemAccessibilitySettingsOpener()
    ) {
        self.permissionChecker = permissionChecker
        self.settingsOpener = settingsOpener
    }

    func reminderIfNeeded(for trigger: AccessibilityPermissionReminderTrigger) -> Bool {
        guard permissionChecker.isProcessTrusted() == false else {
            return false
        }

        switch trigger {
        case .launch:
            guard didRemindOnLaunch == false else {
                return false
            }
            didRemindOnLaunch = true
            return true
        case .automaticPaste:
            guard didRemindForAutomaticPaste == false else {
                return false
            }
            didRemindForAutomaticPaste = true
            return true
        }
    }

    func openSystemSettings() {
        guard let url = Self.systemSettingsURL else {
            return
        }
        settingsOpener.open(url)
    }
}

struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }
}

private final class SystemAccessibilitySettingsOpener: AccessibilitySettingsOpening {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
