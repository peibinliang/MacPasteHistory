import Combine
import Foundation

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable(version: String)
    case failed(message: String)

    var isChecking: Bool {
        self == .checking
    }

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .checking:
            return L10n.string("Checking for updates…")
        case .upToDate:
            return L10n.string("You're up to date.")
        case let .updateAvailable(version):
            return String(format: L10n.string("Update %@ is available."), version)
        case let .failed(message):
            return String(format: L10n.string("Update check failed: %@"), message)
        }
    }

    var errorMessage: String? {
        guard case let .failed(message) = self else {
            return nil
        }
        return message
    }
}

@MainActor
protocol UpdateDriving: AnyObject {
    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> { get }
    var automaticallyChecksForUpdatesPublisher: AnyPublisher<Bool, Never> { get }
    var statusPublisher: AnyPublisher<UpdateStatus, Never> { get }
    var automaticallyChecksForUpdates: Bool { get set }

    func checkForUpdates()
}

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var status = UpdateStatus.idle

    private let driver: UpdateDriving

    init(driver: UpdateDriving) {
        self.driver = driver
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates

        driver.canCheckForUpdatesPublisher
            .removeDuplicates()
            .assign(to: &$canCheckForUpdates)

        driver.automaticallyChecksForUpdatesPublisher
            .removeDuplicates()
            .assign(to: &$automaticallyChecksForUpdates)

        driver.statusPublisher
            .removeDuplicates()
            .assign(to: &$status)
    }

    var isCheckingForUpdates: Bool { status.isChecking }

    var canStartManualUpdateCheck: Bool {
        canCheckForUpdates && !isCheckingForUpdates
    }

    var statusMessage: String? { status.message }

    var errorMessage: String? { status.errorMessage }

    func checkForUpdates() {
        guard canStartManualUpdateCheck else {
            return
        }
        status = .checking
        driver.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        driver.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
    }
}
