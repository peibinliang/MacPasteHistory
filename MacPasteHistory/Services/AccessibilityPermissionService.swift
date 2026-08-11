import AppKit
import ApplicationServices
import Foundation

enum AccessibilityPermissionReminderTrigger {
    case automaticPaste
}

protocol AccessibilityPermissionChecking {
    func isProcessTrusted() -> Bool
}

protocol AccessibilitySettingsOpening: AnyObject {
    func open(_ url: URL)
}

protocol AccessibilityPermissionServing: AnyObject {
    var hasAccessibilityPermission: Bool { get }
    func openSystemSettings()
}

final class AccessibilityPermissionService: AccessibilityPermissionServing {
    static let systemSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    private let permissionChecker: AccessibilityPermissionChecking
    private let settingsOpener: AccessibilitySettingsOpening
    private var didRemindForAutomaticPaste = false

    init(
        permissionChecker: AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
        settingsOpener: AccessibilitySettingsOpening = SystemAccessibilitySettingsOpener()
    ) {
        self.permissionChecker = permissionChecker
        self.settingsOpener = settingsOpener
    }

    func reminderIfNeeded(for trigger: AccessibilityPermissionReminderTrigger) -> Bool {
        guard hasAccessibilityPermission == false else {
            return false
        }

        switch trigger {
        case .automaticPaste:
            guard didRemindForAutomaticPaste == false else {
                return false
            }
            didRemindForAutomaticPaste = true
            return true
        }
    }

    var hasAccessibilityPermission: Bool {
        permissionChecker.isProcessTrusted()
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
