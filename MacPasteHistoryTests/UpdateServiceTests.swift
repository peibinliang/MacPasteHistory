import Combine
import XCTest
@testable import MacPasteHistory

@MainActor
final class UpdateServiceTests: XCTestCase {
    func testCheckForUpdates_whenAvailable_shouldInvokeDriver() {
        let driver = FakeUpdateDriver(canCheckForUpdates: true)
        let service = UpdateService(driver: driver)

        service.checkForUpdates()

        XCTAssertEqual(driver.checkCount, 1)
    }

    func testCheckForUpdates_whenUnavailable_shouldNotInvokeDriver() {
        let driver = FakeUpdateDriver(canCheckForUpdates: false)
        let service = UpdateService(driver: driver)

        service.checkForUpdates()

        XCTAssertEqual(driver.checkCount, 0)
    }

    func testCanCheckForUpdates_whenDriverPublishesChange_shouldUpdateService() {
        let driver = FakeUpdateDriver(canCheckForUpdates: false)
        let service = UpdateService(driver: driver)

        driver.setCanCheckForUpdates(true)

        XCTAssertTrue(service.canCheckForUpdates)
    }

    func testAutomaticChecks_shouldReadAndWriteSparklePreference() {
        let driver = FakeUpdateDriver(
            canCheckForUpdates: true,
            automaticallyChecksForUpdates: true
        )
        let service = UpdateService(driver: driver)

        service.setAutomaticallyChecksForUpdates(false)

        XCTAssertFalse(service.automaticallyChecksForUpdates)
        XCTAssertFalse(driver.automaticallyChecksForUpdates)
    }
}

@MainActor
private final class FakeUpdateDriver: UpdateDriving {
    private let canCheckSubject: CurrentValueSubject<Bool, Never>
    var automaticallyChecksForUpdates: Bool
    private(set) var checkCount = 0

    init(canCheckForUpdates: Bool, automaticallyChecksForUpdates: Bool = true) {
        canCheckSubject = CurrentValueSubject(canCheckForUpdates)
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        canCheckSubject.eraseToAnyPublisher()
    }

    func checkForUpdates() {
        checkCount += 1
    }

    func setCanCheckForUpdates(_ canCheckForUpdates: Bool) {
        canCheckSubject.send(canCheckForUpdates)
    }
}
