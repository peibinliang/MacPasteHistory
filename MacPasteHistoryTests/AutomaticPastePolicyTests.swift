import XCTest
@testable import MacPasteHistory

final class AutomaticPastePolicyTests: XCTestCase {
    func testReadiness_whenDisabled_shouldUseClipboardOnlyWithoutPermission() {
        let context = makeContext(enabled: false, hasPermission: false)

        XCTAssertEqual(context.policy.readiness, .clipboardOnly)
    }

    func testReadiness_whenEnabledWithoutPermission_shouldRequirePermission() {
        let context = makeContext(enabled: true, hasPermission: false)

        XCTAssertEqual(context.policy.readiness, .permissionRequired)
    }

    func testReadiness_whenEnabledWithPermission_shouldBeReady() {
        let context = makeContext(enabled: true, hasPermission: true)

        XCTAssertEqual(context.policy.readiness, .ready)
    }

    private func makeContext(
        enabled: Bool,
        hasPermission: Bool
    ) -> (policy: AutomaticPastePolicy, defaults: UserDefaults) {
        let suiteName = "AutomaticPastePolicyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        var config = UserDefaultsConfig(defaults: defaults)
        config.automaticPasteEnabled = enabled
        return (
            AutomaticPastePolicy(
                config: config,
                accessibilityPermissionService: AutomaticPasteFakePermissionService(
                    hasPermission: hasPermission
                )
            ),
            defaults
        )
    }
}

private final class AutomaticPasteFakePermissionService: AccessibilityPermissionServing {
    let hasAccessibilityPermission: Bool

    init(hasPermission: Bool) {
        hasAccessibilityPermission = hasPermission
    }

    func openSystemSettings() {}
}
