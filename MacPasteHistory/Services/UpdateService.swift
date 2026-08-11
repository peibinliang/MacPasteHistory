import Combine

@MainActor
protocol UpdateDriving: AnyObject {
    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> { get }
    var automaticallyChecksForUpdates: Bool { get set }

    func checkForUpdates()
}

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates: Bool

    private let driver: UpdateDriving

    init(driver: UpdateDriving) {
        self.driver = driver
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates

        driver.canCheckForUpdatesPublisher
            .removeDuplicates()
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            return
        }
        driver.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        driver.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
    }
}
