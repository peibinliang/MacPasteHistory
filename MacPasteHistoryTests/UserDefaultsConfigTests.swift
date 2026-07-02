import XCTest
@testable import MacPasteHistory

final class UserDefaultsConfigTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacPasteHistoryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testTotalStorageCapInBytes_shouldPersistConfiguredValue() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.totalStorageCapInBytes = 500 * 1024 * 1024

        let reloadedConfig = UserDefaultsConfig(defaults: defaults)
        XCTAssertEqual(reloadedConfig.totalStorageCapInBytes, 500 * 1024 * 1024)
    }

    func testTotalStorageCapInBytes_whenUnset_shouldUseDefaultValue() {
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.totalStorageCapInBytes, DefaultSettings.totalStorageCapInBytes)
    }
}
