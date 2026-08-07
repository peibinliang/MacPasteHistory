import XCTest
import ApplicationServices
@testable import MacPasteHistory

final class AccessibilityPermissionServiceTests: XCTestCase {
    func testReminderIfNeeded_onFirstLaunchWithoutPermission_shouldReturnReminderOnce() {
        let service = AccessibilityPermissionService(
            permissionChecker: FakeAccessibilityPermissionChecker(isTrusted: false),
            settingsOpener: FakeAccessibilitySettingsOpener()
        )

        XCTAssertTrue(service.reminderIfNeeded(for: .launch))
        XCTAssertFalse(service.reminderIfNeeded(for: .launch))
    }

    func testReminderIfNeeded_onAutomaticPasteWithoutPermission_shouldReturnReminderOnce() {
        let service = AccessibilityPermissionService(
            permissionChecker: FakeAccessibilityPermissionChecker(isTrusted: false),
            settingsOpener: FakeAccessibilitySettingsOpener()
        )

        XCTAssertTrue(service.reminderIfNeeded(for: .automaticPaste))
        XCTAssertFalse(service.reminderIfNeeded(for: .automaticPaste))
    }

    func testReminderIfNeeded_whenPermissionIsGranted_shouldNotReturnReminder() {
        let service = AccessibilityPermissionService(
            permissionChecker: FakeAccessibilityPermissionChecker(isTrusted: true),
            settingsOpener: FakeAccessibilitySettingsOpener()
        )

        XCTAssertFalse(service.reminderIfNeeded(for: .launch))
        XCTAssertFalse(service.reminderIfNeeded(for: .automaticPaste))
        XCTAssertTrue(service.hasAccessibilityPermission)
    }

    func testPermissionState_remainsDeniedAfterOneTimeReminderWasConsumed() {
        let service = AccessibilityPermissionService(
            permissionChecker: FakeAccessibilityPermissionChecker(isTrusted: false),
            settingsOpener: FakeAccessibilitySettingsOpener()
        )

        XCTAssertTrue(service.reminderIfNeeded(for: .automaticPaste))
        XCTAssertFalse(service.reminderIfNeeded(for: .automaticPaste))
        XCTAssertFalse(service.hasAccessibilityPermission)
    }

    func testOpenSystemSettings_shouldOpenAccessibilityPrivacyPane() {
        let settingsOpener = FakeAccessibilitySettingsOpener()
        let service = AccessibilityPermissionService(
            permissionChecker: FakeAccessibilityPermissionChecker(isTrusted: false),
            settingsOpener: settingsOpener
        )

        service.openSystemSettings()

        XCTAssertEqual(settingsOpener.openedURL, AccessibilityPermissionService.systemSettingsURL)
    }

    func testSystemPermissionChecker_shouldReflectMacOSAccessibilityState() {
        let checker = SystemAccessibilityPermissionChecker()

        XCTAssertEqual(checker.isProcessTrusted(), AXIsProcessTrusted())
    }
}

private struct FakeAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    let isTrusted: Bool

    func isProcessTrusted() -> Bool {
        isTrusted
    }
}

private final class FakeAccessibilitySettingsOpener: AccessibilitySettingsOpening {
    private(set) var openedURL: URL?

    func open(_ url: URL) {
        openedURL = url
    }
}
