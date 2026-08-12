import AppKit
import Combine
import SwiftUI

enum AppLaunchPolicy {
    static let appSupportOverrideEnvironmentKey = "MACPASTEHISTORY_APP_SUPPORT_DIR"
    static let openHistoryEnvironmentKey = "MACPASTEHISTORY_OPEN_HISTORY_ON_LAUNCH"
    static let userDefaultsSuiteEnvironmentKey = "MACPASTEHISTORY_USER_DEFAULTS_SUITE"
    private static let qaSuitePrefix = "com.peibin.MacPasteHistory.qa."

    static func shouldOpenHistory(environment: [String: String]) -> Bool {
        guard let appSupportPath = environment[appSupportOverrideEnvironmentKey],
              appSupportPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let requestedValue = environment[openHistoryEnvironmentKey]?.lowercased() else {
            return false
        }
        return ["1", "true", "yes"].contains(requestedValue)
    }

    static func isolatedUserDefaultsSuiteName(environment: [String: String]) -> String? {
        guard let appSupportPath = environment[appSupportOverrideEnvironmentKey],
              appSupportPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let suiteName = environment[userDefaultsSuiteEnvironmentKey],
              suiteName.hasPrefix(qaSuitePrefix),
              suiteName.count <= 255,
              suiteName.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return suiteName
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let xctestConfigurationEnvironmentKey = "XCTestConfigurationFilePath"

    private let logger = Logger(category: "AppDelegate")
    private lazy var applicationSupportService = ApplicationSupportService(
        applicationSupportOverrideURL: Self.applicationSupportOverrideURL()
    )
    private let restorationState = ClipboardRestorationState()
    private lazy var databaseInitializer = DatabaseInitializer(
        applicationSupportService: applicationSupportService,
        logger: Logger(category: "DatabaseInitializer")
    )
    private var statusItem: NSStatusItem?
    private var mainWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    private var clipboardHistoryRepository: ClipboardHistoryRepository?
    private var clipboardWriter: ClipboardWriter?
    private var imageStorageService: ImageStorageService?
    private var clipboardMonitor: ClipboardMonitor?
    private var searchCoordinator: SearchCoordinator?
    private var aiTokenUsageRepository: AITokenUsageRepository?
    private var clearDataCancellable: AnyCancellable?
    private let shortcutService: ShortcutService
    private var shortcutCancellable: AnyCancellable?
    private var workspaceActivationCancellable: AnyCancellable?
    private var lastExternalApplication: NSRunningApplication?
    private let appPreferencesService = AppPreferencesService()
    private let appearanceService = AppearanceService()
    private let accessibilityPermissionService: AccessibilityPermissionService
    private lazy var updateService = UpdateService(driver: SparkleUpdateDriver())

    override init() {
        shortcutService = Self.makeRuntimeShortcutService()
        accessibilityPermissionService = AccessibilityPermissionService()
        super.init()
    }

    init(shortcutService: ShortcutService) {
        self.shortcutService = shortcutService
        accessibilityPermissionService = AccessibilityPermissionService()
        super.init()
    }

    static func makeRuntimeShortcutService(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ShortcutService {
        let config = UserDefaultsConfig(environment: environment)
        if config.isIsolatedQASession {
            return ShortcutService(
                config: config,
                registrationManager: IsolatedQAShortcutRegistrationManager()
            )
        }
        return ShortcutService(config: config)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LanguageManager(defaults: UserDefaultsConfig().backingDefaults).applyCurrentLanguage()
        configureApplication()
        initializeLocalStorage()
        guard Self.isRunningUnderXCTest == false else {
            return
        }
        createStatusItem()
        setupPasteTargetTracking()
        clipboardMonitor?.start()
        setupClearDataObserver()
        setupShortcut()
        if AppLaunchPolicy.shouldOpenHistory(environment: ProcessInfo.processInfo.environment) {
            openMainPanel()
        }
    }

    private static func applicationSupportOverrideURL() -> URL? {
        let processInfo = ProcessInfo.processInfo
        if let path = processInfo.environment[AppLaunchPolicy.appSupportOverrideEnvironmentKey],
           path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        guard isRunningUnderXCTest else {
            return nil
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("MacPasteHistory-XCTest-\(processInfo.processIdentifier)", isDirectory: true)
    }

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment[xctestConfigurationEnvironmentKey] != nil
    }

    private func setupClearDataObserver() {
        clearDataCancellable = NotificationCenter.default
            .publisher(for: .clearAllDataRequested)
            .sink { [weak self] _ in
                self?.handleClearAllData()
            }
    }

    private func setupShortcut() {
        shortcutService.registerConfiguredShortcut()
        shortcutCancellable = NotificationCenter.default
            .publisher(for: .globalShortcutPressed)
            .sink { [weak self] _ in
                self?.openMainPanel()
            }
    }

    private func setupPasteTargetTracking() {
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        workspaceActivationCancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
                self?.rememberExternalApplication(application)
            }
    }

    private func rememberExternalApplication(_ application: NSRunningApplication?) {
        guard application?.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }
        lastExternalApplication = application
    }

    private func handleClearAllData() {
        guard let repository = clipboardHistoryRepository,
              let imageStorageService else {
            return
        }
        do {
            try ClipboardDataClearService(
                repository: repository,
                imageStorageService: imageStorageService,
                aiTokenUsageRepository: aiTokenUsageRepository
            ).clearAllData()
            logger.info("All clipboard data cleared")
        } catch {
            logger.error("Failed to clear all data: \(error.localizedDescription)")
        }
    }

    private func configureApplication() {
        appPreferencesService.applyDockIconPreference()
        appearanceService.applyCurrentAppearance()
    }

    private func createStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let statusIcon = NSImage(named: "StatusBarIcon") ?? NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: AppBrand.displayName
        )
        statusIcon?.isTemplate = true
        statusItem.button?.image = statusIcon
        statusItem.button?.toolTip = AppBrand.displayName
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openMainPanel)
        statusItem.menu = createStatusMenu()
        self.statusItem = statusItem
    }

    private func createStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.string("Open History"), action: #selector(openMainPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.string("Settings"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.string("Quit"), action: #selector(quitApplication), keyEquivalent: "q"))
        menu.items.forEach { item in
            item.target = self
        }
        return menu
    }

    private func initializeLocalStorage() {
        do {
            try applicationSupportService.createRequiredDirectories()
            try databaseInitializer.initializeDatabase()
            guard let database = databaseInitializer.currentDatabase() else {
                logger.error("Database connection unavailable after initialization")
                return
            }
            let repository = ClipboardHistoryRepository(database: database)
            let writer = ClipboardWriter(restorationState: restorationState)
            let imageStorageService = ImageStorageService(
                imagesDirectory: try applicationSupportService.imagesURL,
                thumbnailsDirectory: try applicationSupportService.thumbnailsURL,
                maxImageSizeInBytesProvider: { UserDefaultsConfig().maxImageSizeInBytes }
            )
            clipboardHistoryRepository = repository
            aiTokenUsageRepository = AITokenUsageRepository(database: database)
            clipboardWriter = writer
            self.imageStorageService = imageStorageService
            clipboardMonitor = ClipboardMonitor(
                repository: repository,
                imageStorageService: imageStorageService,
                restorationState: restorationState
            )
            searchCoordinator = SearchCoordinator(
                provider: SearchCandidateProvider(databaseURL: try applicationSupportService.databaseURL)
            )
            logger.info("Local storage initialized")

            // Perform data cleanup on startup (expired records, count limits, storage caps)
            let cleanupService = DataCleanupService(
                repository: repository,
                imageStorageService: imageStorageService,
                captureEventAggregationService: CaptureEventAggregationService(
                    repository: repository,
                    preferences: makeCaptureEventAggregationPreferences()
                )
            )
            cleanupService.performStartupCleanup()
            startStorageReconciliation()
        } catch {
            logger.error("Local storage initialization failed: \(error.localizedDescription)")
        }
    }

    private func startStorageReconciliation() {
        do {
            let databaseURL = try applicationSupportService.databaseURL
            let imagesURL = try applicationSupportService.imagesURL
            let thumbnailsURL = try applicationSupportService.thumbnailsURL
            let temporaryURL = try applicationSupportService.reconciliationTemporaryURL
            DispatchQueue.global(qos: .utility).async {
                let reconciliationLogger = Logger(category: "StorageReconciliation")
                do {
                    let database = try DatabaseConnection(databaseURL: databaseURL, mode: .readOnly)
                    defer { try? database.close() }
                    let report = StorageReconciliationService(
                        repository: ClipboardHistoryRepository(database: database),
                        imagesDirectory: imagesURL,
                        thumbnailsDirectory: thumbnailsURL,
                        temporaryDirectory: temporaryURL
                    ).reconcile()
                    let issueCount = report.issueCounts.values.reduce(0, +)
                    reconciliationLogger.info(
                        "Storage reconciliation completed, issues: \(issueCount), "
                            + "planned: \(report.plannedActionCount), "
                            + "completed: \(report.completedActionCount), failed: \(report.failedActionCount)"
                    )
                } catch {
                    reconciliationLogger.error("Storage reconciliation could not start")
                }
            }
        } catch {
            logger.error("Storage reconciliation paths unavailable")
        }
    }

    @objc private func openMainPanel() {
        guard let clipboardHistoryRepository, let clipboardWriter else {
            logger.error("Cannot open history before local storage is initialized")
            return
        }
        let pasteTargetApplication = currentPasteTargetApplication()
        let viewModel = ClipboardHistoryViewModel(
            repository: clipboardHistoryRepository,
            writer: clipboardWriter,
            imageStorageService: imageStorageService,
            searchCoordinator: searchCoordinator
        )
        let controller = mainWindowController ?? createHistoryPanelController(
            viewModel: viewModel,
            pasteCoordinator: makePasteCoordinator(
                viewModel: viewModel,
                targetApplication: pasteTargetApplication
            )
        )
        if let hostingView = controller.window?.contentView as? NSHostingView<MainPanelView> {
            hostingView.rootView = MainPanelView(
                viewModel: viewModel,
                accessibilityPermissionService: accessibilityPermissionService,
                actionViewModel: makeContentActionViewModel(),
                pasteCoordinator: makePasteCoordinator(
                    viewModel: viewModel,
                    targetApplication: pasteTargetApplication
                ),
                dismissAction: { [weak window = controller.window] in
                    window?.orderOut(nil)
                }
            )
        }
        mainWindowController = controller
        showHistoryPanel(controller)
    }

    private func currentPasteTargetApplication() -> NSRunningApplication? {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let preferredBundleIdentifier = PasteTargetPolicy.preferredBundleIdentifier(
            frontmostBundleIdentifier: frontmostApplication?.bundleIdentifier,
            lastExternalBundleIdentifier: lastExternalApplication?.bundleIdentifier,
            ownBundleIdentifier: Bundle.main.bundleIdentifier
        )

        if frontmostApplication?.bundleIdentifier == preferredBundleIdentifier {
            rememberExternalApplication(frontmostApplication)
            return frontmostApplication
        }
        return lastExternalApplication?.bundleIdentifier == preferredBundleIdentifier
            ? lastExternalApplication
            : nil
    }

    func makeSettingsViewModel(
        config: UserDefaultsConfig = UserDefaultsConfig()
    ) -> SettingsViewModel {
        SettingsViewModel(
            config: config,
            loginItemService: makeLoginItemService(config: config),
            languageManager: LanguageManager(defaults: config.backingDefaults),
            appearanceService: AppearanceService(config: config),
            shortcutService: makeSettingsShortcutService(config: config),
            accessibilityPermissionService: accessibilityPermissionService,
            aiCredentialStore: KeychainAICredentialStore(),
            aiTokenUsageRepository: aiTokenUsageRepository
        )
    }

    func makeLoginItemService(config: UserDefaultsConfig = UserDefaultsConfig()) -> LoginItemService {
        if config.isIsolatedQASession {
            return LoginItemService(manager: IsolatedQALoginItemManager(), config: config)
        }
        return LoginItemService(manager: SystemLoginItemManager(), config: config)
    }

    func makeSettingsShortcutService(config: UserDefaultsConfig = UserDefaultsConfig()) -> ShortcutService {
        if config.isIsolatedQASession {
            return ShortcutService(
                config: config,
                registrationManager: IsolatedQAShortcutRegistrationManager()
            )
        }
        return shortcutService
    }

    func makeCaptureEventAggregationPreferences(
        config: UserDefaultsConfig = UserDefaultsConfig()
    ) -> CaptureEventAggregationPreferences {
        CaptureEventAggregationPreferences(defaults: config.backingDefaults)
    }

    func makeUpdateService() -> UpdateService {
        updateService
    }

    private func makeContentActionViewModel() -> ContentActionPanelViewModel {
        let config = UserDefaultsConfig()
        let polishingAction = AITextPolishingAction(
            service: AITextPolishingService(
                config: config,
                usageRepository: aiTokenUsageRepository
            )
        )
        let registry = ContentActionRegistry(
            actions: ContentActionRegistry.defaultActions + [polishingAction]
        )
        return ContentActionPanelViewModel(registry: registry, config: config)
    }

    @objc private func openSettings() {
        let controller = settingsWindowController ?? createWindowController(
            title: L10n.string("Settings"),
            rootView: SettingsView(
                viewModel: makeSettingsViewModel(),
                updateService: makeUpdateService()
            ),
            size: NSSize(width: 520, height: 420)
        )
        settingsWindowController = controller
        showWindow(controller)
    }

    @objc private func quitApplication() {
        clipboardMonitor?.stop()
        NSApp.terminate(nil)
    }

    private func createWindowController<Content: View>(
        title: String,
        rootView: Content,
        size: NSSize
    ) -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.contentView = NSHostingView(rootView: rootView)
        return NSWindowController(window: window)
    }

    private func createHistoryPanelController(
        viewModel: ClipboardHistoryViewModel,
        pasteCoordinator: PasteCoordinator
    ) -> NSWindowController {
        let panel = HistoryPanelWindow(
            contentRect: NSRect(origin: .zero, size: HistoryPanelWindow.defaultSize)
        )
        panel.contentView = NSHostingView(
            rootView: MainPanelView(
                viewModel: viewModel,
                accessibilityPermissionService: accessibilityPermissionService,
                actionViewModel: makeContentActionViewModel(),
                pasteCoordinator: pasteCoordinator,
                dismissAction: { [weak panel] in
                    panel?.orderOut(nil)
                }
            )
        )
        return NSWindowController(window: panel)
    }

    private func makePasteCoordinator(
        viewModel: ClipboardHistoryViewModel,
        targetApplication: NSRunningApplication?
    ) -> PasteCoordinator {
        PasteCoordinator(
            writer: viewModel,
            readinessProvider: AutomaticPastePolicy(
                accessibilityPermissionService: accessibilityPermissionService
            ),
            target: targetApplication.map(RunningApplicationPasteTarget.init(application:)),
            commandDispatcher: PasteCommandService(),
            usageRecorder: viewModel
        )
    }

    private func showHistoryPanel(_ controller: NSWindowController) {
        guard let panel = controller.window as? HistoryPanelWindow else {
            return
        }
        panel.resizeForActiveScreen()
        panel.positionOnActiveScreen()
        controller.showWindow(nil)
        panel.makeKeyAndOrderFront(nil)
    }

    private func showWindow(_ controller: NSWindowController) {
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
