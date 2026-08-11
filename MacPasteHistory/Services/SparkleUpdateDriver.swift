import AppKit
import Combine
@preconcurrency import Sparkle

@MainActor
final class UpdateReminderPresenter {
    private let currentActivationPolicy: () -> NSApplication.ActivationPolicy
    private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool
    private let setDockBadge: (String?) -> Void
    private let shouldKeepDockIconVisible: () -> Bool
    private var temporarilyPromotedToRegular = false

    init(
        currentActivationPolicy: @escaping () -> NSApplication.ActivationPolicy = {
            NSApp.activationPolicy()
        },
        setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Bool = {
            NSApp.setActivationPolicy($0)
        },
        setDockBadge: @escaping (String?) -> Void = {
            NSApp.dockTile.badgeLabel = $0
        },
        shouldKeepDockIconVisible: @escaping () -> Bool = {
            UserDefaultsConfig().showDockIcon
        }
    ) {
        self.currentActivationPolicy = currentActivationPolicy
        self.setActivationPolicy = setActivationPolicy
        self.setDockBadge = setDockBadge
        self.shouldKeepDockIconVisible = shouldKeepDockIconVisible
    }

    func willShowUpdate(userInitiated: Bool) {
        if currentActivationPolicy() == .accessory,
           setActivationPolicy(.regular) {
            temporarilyPromotedToRegular = true
        }
        if !userInitiated {
            setDockBadge("1")
        }
    }

    func didReceiveUserAttention() {
        setDockBadge(nil)
    }

    func didFinishUpdateSession() {
        setDockBadge(nil)
        if temporarilyPromotedToRegular, !shouldKeepDockIconVisible() {
            _ = setActivationPolicy(.accessory)
        }
        temporarilyPromotedToRegular = false
    }
}

@MainActor
final class SparkleUpdateDriver: NSObject, UpdateDriving, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private let startingUpdater: Bool
    private let reminderPresenter: UpdateReminderPresenter
    private let statusSubject = CurrentValueSubject<UpdateStatus, Never>(.idle)
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: startingUpdater,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    init(
        startingUpdater: Bool = true,
        reminderPresenter: UpdateReminderPresenter = UpdateReminderPresenter()
    ) {
        self.startingUpdater = startingUpdater
        self.reminderPresenter = reminderPresenter
        super.init()
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
        controller.updater.publisher(for: \.canCheckForUpdates).eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdatesPublisher: AnyPublisher<Bool, Never> {
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).eraseToAnyPublisher()
    }

    var statusPublisher: AnyPublisher<UpdateStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        statusSubject.send(.checking)
        controller.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        statusSubject.send(.updateAvailable(version: item.displayVersionString))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        statusSubject.send(.upToDate)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let error = error as NSError
        if error.domain == SUSparkleErrorDomain,
           error.code == Int(SUError.noUpdateError.rawValue) {
            statusSubject.send(.upToDate)
            return
        }
        statusSubject.send(.failed(message: error.localizedDescription))
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        reminderPresenter.willShowUpdate(userInitiated: state.userInitiated)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        reminderPresenter.didReceiveUserAttention()
    }

    func standardUserDriverWillFinishUpdateSession() {
        reminderPresenter.didFinishUpdateSession()
    }
}
