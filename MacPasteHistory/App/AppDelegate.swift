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
    private var clearDataCancellable: AnyCancellable?
    private let shortcutService = ShortcutService()
    private var shortcutCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplication()
        initializeLocalStorage()
        createStatusItem()
        clipboardMonitor?.start()
        setupClearDataObserver()
        setupShortcut()
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
        shortcutService.registerDefaultShortcut()
        shortcutCancellable = NotificationCenter.default
            .publisher(for: .globalShortcutPressed)
            .sink { [weak self] _ in
                self?.openMainPanel()
            }
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
        NSApp.setActivationPolicy(.accessory)
    }

    private func createStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "MacPasteHistory"
        )
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openMainPanel)
        statusItem.menu = createStatusMenu()
        self.statusItem = statusItem
    }

    private func createStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open History", action: #selector(openMainPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q"))
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
            logger.info("Local storage initialized")

            // Perform data cleanup on startup (expired records, count limits, storage caps)
            let cleanupService = DataCleanupService(
                repository: repository,
                imageStorageService: imageStorageService
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
        let pasteTargetApplication = Self.currentPasteTargetApplication()
        let viewModel = ClipboardHistoryViewModel(
            repository: clipboardHistoryRepository,
            writer: clipboardWriter,
            imageStorageService: imageStorageService
        )
        let controller = mainWindowController ?? createWindowController(
            title: "Clipboard History",
            rootView: MainPanelView(
                viewModel: viewModel,
                pasteTargetApplication: pasteTargetApplication
            ),
            size: NSSize(width: 520, height: 640)
        )
        if let hostingView = controller.window?.contentView as? NSHostingView<MainPanelView> {
            hostingView.rootView = MainPanelView(
                viewModel: viewModel,
                pasteTargetApplication: pasteTargetApplication
            )
        }
        mainWindowController = controller
        showWindow(controller)
    }

    private static func currentPasteTargetApplication() -> NSRunningApplication? {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        guard frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return frontmostApplication
    }

    @objc private func openSettings() {
        let controller = settingsWindowController ?? createWindowController(
            title: "Settings",
            rootView: SettingsView(),
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

    private func showWindow(_ controller: NSWindowController) {
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
