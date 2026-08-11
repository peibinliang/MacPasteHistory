import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let appSupportOverrideEnvironmentKey = "MACPASTEHISTORY_APP_SUPPORT_DIR"

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
        shortcutService = ShortcutService()
        accessibilityPermissionService = AccessibilityPermissionService()
        super.init()
    }

    init(shortcutService: ShortcutService) {
        self.shortcutService = shortcutService
        accessibilityPermissionService = AccessibilityPermissionService()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LanguageManager().applyCurrentLanguage()
        configureApplication()
        initializeLocalStorage()
        createStatusItem()
        setupPasteTargetTracking()
        clipboardMonitor?.start()
        setupClearDataObserver()
        setupShortcut()
        scheduleLaunchAccessibilityPermissionReminder()
    }

    private static func applicationSupportOverrideURL() -> URL? {
        guard let path = ProcessInfo.processInfo.environment[appSupportOverrideEnvironmentKey],
              path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
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

    private func scheduleLaunchAccessibilityPermissionReminder() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.presentLaunchAccessibilityPermissionReminderIfNeeded()
        }
    }

    private func presentLaunchAccessibilityPermissionReminderIfNeeded() {
        guard accessibilityPermissionService.reminderIfNeeded(for: .launch) else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.string("Accessibility Permission Required")
        alert.informativeText = L10n.string(
            "Allow 粘易 in System Settings → Privacy & Security → Accessibility, then try pasting again."
        )
        alert.addButton(withTitle: L10n.string("Open System Settings"))
        alert.addButton(withTitle: L10n.string("Later"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            accessibilityPermissionService.openSystemSettings()
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
                imageStorageService: imageStorageService
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
                    preferences: CaptureEventAggregationPreferences(defaults: .standard)
                )
            )
            cleanupService.performStartupCleanup()
        } catch {
            logger.error("Local storage initialization failed: \(error.localizedDescription)")
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
            pasteTargetApplication: pasteTargetApplication
        )
        if let hostingView = controller.window?.contentView as? NSHostingView<MainPanelView> {
            hostingView.rootView = MainPanelView(
                viewModel: viewModel,
                accessibilityPermissionService: accessibilityPermissionService,
                pasteTargetApplication: pasteTargetApplication,
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
            appearanceService: AppearanceService(config: config),
            shortcutService: shortcutService
        )
    }

    func makeUpdateService() -> UpdateService {
        updateService
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
        pasteTargetApplication: NSRunningApplication?
    ) -> NSWindowController {
        let panel = HistoryPanelWindow(
            contentRect: NSRect(origin: .zero, size: HistoryPanelWindow.defaultSize)
        )
        panel.contentView = NSHostingView(
            rootView: MainPanelView(
                viewModel: viewModel,
                accessibilityPermissionService: accessibilityPermissionService,
                pasteTargetApplication: pasteTargetApplication,
                dismissAction: { [weak panel] in
                    panel?.orderOut(nil)
                }
            )
        )
        return NSWindowController(window: panel)
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
