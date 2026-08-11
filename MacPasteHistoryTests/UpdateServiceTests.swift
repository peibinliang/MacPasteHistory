import AppKit
import Combine
import Sparkle
import XCTest
@testable import MacPasteHistory

@MainActor
final class UpdateServiceTests: XCTestCase {
    func testCheckForUpdates_whenAvailable_shouldInvokeDriver() {
        let driver = FakeUpdateDriver(canCheckForUpdates: true)
        let service = UpdateService(driver: driver)

        service.checkForUpdates()

        XCTAssertEqual(driver.checkCount, 1)
        XCTAssertEqual(service.status, .checking)
        XCTAssertTrue(service.isCheckingForUpdates)
        XCTAssertFalse(service.canStartManualUpdateCheck)
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

    func testAutomaticChecks_whenDriverPublishesChange_shouldUpdateService() {
        let driver = FakeUpdateDriver(
            canCheckForUpdates: true,
            automaticallyChecksForUpdates: true
        )
        let service = UpdateService(driver: driver)

        driver.setAutomaticallyChecksForUpdates(false)

        XCTAssertFalse(service.automaticallyChecksForUpdates)
    }

    func testStatus_whenDriverPublishesUpdateEvents_shouldExposeLatestResult() {
        let driver = FakeUpdateDriver(canCheckForUpdates: true)
        let service = UpdateService(driver: driver)

        driver.sendStatus(.upToDate)
        XCTAssertEqual(service.status, .upToDate)
        XCTAssertEqual(service.statusMessage, L10n.string("You're up to date."))

        driver.sendStatus(.updateAvailable(version: "1.0.2"))
        XCTAssertEqual(service.status, .updateAvailable(version: "1.0.2"))
        XCTAssertEqual(
            service.statusMessage,
            String(format: L10n.string("Update %@ is available."), "1.0.2")
        )

        driver.sendStatus(.failed(message: "The appcast could not be loaded."))
        XCTAssertEqual(service.status, .failed(message: "The appcast could not be loaded."))
        XCTAssertEqual(service.errorMessage, "The appcast could not be loaded.")
    }

    func testGentleReminderPresenter_whenScheduledUpdateAppears_shouldMakeDockVisibleUntilSessionFinishes() {
        var activationPolicy = NSApplication.ActivationPolicy.accessory
        var appliedPolicies: [NSApplication.ActivationPolicy] = []
        var badges: [String?] = []
        let presenter = UpdateReminderPresenter(
            currentActivationPolicy: { activationPolicy },
            setActivationPolicy: { policy in
                activationPolicy = policy
                appliedPolicies.append(policy)
                return true
            },
            setDockBadge: { badges.append($0) }
        )

        presenter.willShowUpdate(userInitiated: false)

        XCTAssertEqual(appliedPolicies, [.regular])
        XCTAssertEqual(badges, ["1"])

        presenter.didReceiveUserAttention()
        presenter.didFinishUpdateSession()

        XCTAssertEqual(appliedPolicies, [.regular, .accessory])
        XCTAssertEqual(badges.count, 3)
        XCTAssertEqual(badges.compactMap { $0 }, ["1"])
    }

    func testGentleReminderPresenter_whenDockAlreadyVisible_shouldPreserveUserPreference() {
        var appliedPolicies: [NSApplication.ActivationPolicy] = []
        let presenter = UpdateReminderPresenter(
            currentActivationPolicy: { .regular },
            setActivationPolicy: { policy in
                appliedPolicies.append(policy)
                return true
            },
            setDockBadge: { _ in }
        )

        presenter.willShowUpdate(userInitiated: true)
        presenter.didFinishUpdateSession()

        XCTAssertTrue(appliedPolicies.isEmpty)
    }

    func testSparkleDriver_shouldDeclareGentleScheduledReminderCapability() {
        func requireStandardUserDriverDelegate<T: SPUStandardUserDriverDelegate>(_: T.Type) {}
        requireStandardUserDriverDelegate(SparkleUpdateDriver.self)

        let driver = SparkleUpdateDriver(startingUpdater: false)

        XCTAssertTrue(driver.supportsGentleScheduledUpdateReminders)
    }

    func testSparkleDriver_whenDelegateReportsEvents_shouldPublishRealEventOutcome() {
        let driver = SparkleUpdateDriver(startingUpdater: false)
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        var statuses: [UpdateStatus] = []
        let cancellable = driver.statusPublisher.sink { statuses.append($0) }

        let item = SUAppcastItem.empty()
        driver.updater(updaterController.updater, didFindValidUpdate: item)
        XCTAssertEqual(statuses.last, .updateAvailable(version: item.displayVersionString))

        driver.updater(
            updaterController.updater,
            didAbortWithError: NSError(
                domain: SUSparkleErrorDomain,
                code: Int(SUError.noUpdateError.rawValue)
            )
        )
        XCTAssertEqual(statuses.last, .upToDate)

        driver.updater(
            updaterController.updater,
            didAbortWithError: NSError(
                domain: SUSparkleErrorDomain,
                code: Int(SUError.appcastError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Invalid update feed."]
            )
        )
        XCTAssertEqual(statuses.last, .failed(message: "Invalid update feed."))
        withExtendedLifetime(cancellable) {}
    }
}

@MainActor
private final class FakeUpdateDriver: UpdateDriving {
    private let canCheckSubject: CurrentValueSubject<Bool, Never>
    private let automaticallyChecksSubject: CurrentValueSubject<Bool, Never>
    private let statusSubject = CurrentValueSubject<UpdateStatus, Never>(.idle)
    var automaticallyChecksForUpdates: Bool {
        didSet {
            automaticallyChecksSubject.send(automaticallyChecksForUpdates)
        }
    }
    private(set) var checkCount = 0

    init(canCheckForUpdates: Bool, automaticallyChecksForUpdates: Bool = true) {
        canCheckSubject = CurrentValueSubject(canCheckForUpdates)
        automaticallyChecksSubject = CurrentValueSubject(automaticallyChecksForUpdates)
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        canCheckSubject.eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdatesPublisher: AnyPublisher<Bool, Never> {
        automaticallyChecksSubject.eraseToAnyPublisher()
    }

    var statusPublisher: AnyPublisher<UpdateStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    func checkForUpdates() {
        checkCount += 1
    }

    func setCanCheckForUpdates(_ canCheckForUpdates: Bool) {
        canCheckSubject.send(canCheckForUpdates)
    }

    func setAutomaticallyChecksForUpdates(_ automaticallyChecksForUpdates: Bool) {
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func sendStatus(_ status: UpdateStatus) {
        statusSubject.send(status)
    }
}
