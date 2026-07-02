import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(category: "AppDelegate")
    private let applicationSupportService = ApplicationSupportService()
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplication()
        initializeLocalStorage()
        createStatusItem()
        clipboardMonitor?.start()
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
                thumbnailsDirectory: try applicationSupportService.thumbnailsURL
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
        } catch {
            logger.error("Local storage initialization failed: \(error.localizedDescription)")
        }
    }

    @objc private func openMainPanel() {
        guard let clipboardHistoryRepository, let clipboardWriter else {
            logger.error("Cannot open history before local storage is initialized")
            return
        }
        let viewModel = ClipboardHistoryViewModel(
            repository: clipboardHistoryRepository,
            writer: clipboardWriter,
            imageStorageService: imageStorageService
        )
        let controller = mainWindowController ?? createWindowController(
            title: "Clipboard History",
            rootView: MainPanelView(viewModel: viewModel),
            size: NSSize(width: 520, height: 640)
        )
        mainWindowController = controller
        showWindow(controller)
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
