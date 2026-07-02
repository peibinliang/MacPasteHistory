import AppKit
import Foundation

final class ClipboardMonitor: NSObject {
    private let pasteboard: PasteboardProviding
    private let reader: ClipboardReader
    private let repository: ClipboardHistoryRepository
    private let imageStorageService: ImageStorageService
    private let sourceApplicationProvider: SourceApplicationProviding
    private let restorationState: ClipboardRestorationState
    private let recordingSettings: RecordingSettingsProviding
    private let logger: Logger
    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        pasteboard: PasteboardProviding = NSPasteboard.general,
        reader: ClipboardReader? = nil,
        repository: ClipboardHistoryRepository,
        imageStorageService: ImageStorageService,
        sourceApplicationProvider: SourceApplicationProviding = SourceApplicationProvider(),
        restorationState: ClipboardRestorationState,
        recordingSettings: RecordingSettingsProviding = DefaultRecordingSettingsProvider(),
        logger: Logger = Logger(category: "ClipboardMonitor")
    ) {
        self.pasteboard = pasteboard
        self.reader = reader ?? ClipboardReader(pasteboard: pasteboard)
        self.repository = repository
        self.imageStorageService = imageStorageService
        self.sourceApplicationProvider = sourceApplicationProvider
        self.restorationState = restorationState
        self.recordingSettings = recordingSettings
        self.logger = logger
        self.lastChangeCount = pasteboard.changeCount
        super.init()
    }

    func start() {
        guard timer == nil else {
            return
        }
        timer = Timer.scheduledTimer(
            timeInterval: DefaultSettings.clipboardPollingInterval,
            target: self,
            selector: #selector(handleTimer),
            userInfo: nil,
            repeats: true
        )
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        logger.info("Clipboard monitor started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("Clipboard monitor stopped")
    }

    func pollOnce() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }
        lastChangeCount = pasteboard.changeCount

        guard restorationState.consumeShouldSkipNextChange() == false else {
            logger.info("Skipped internally restored clipboard change")
            return
        }

        if recordingSettings.shouldRecordImage, let image = reader.readImage() {
            saveImage(image)
            return
        }

        guard recordingSettings.shouldRecordText else {
            return
        }
        guard let text = reader.readPlainText() else {
            return
        }
        saveText(text)
    }

    private func saveText(_ text: String) {
        do {
            let sourceApplication = sourceApplicationProvider.currentSourceApplication()
            _ = try repository.saveText(
                text,
                sourceApp: sourceApplication.name,
                sourceBundleID: sourceApplication.bundleID
            )
            logger.info("Clipboard text saved, length: \(text.count)")
            NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
        } catch {
            logger.error("Failed to save clipboard text: \(error.localizedDescription)")
        }
    }

    private func saveImage(_ image: ClipboardImageCandidate) {
        do {
            let storedImage = try imageStorageService.storeImage(image)
            let sourceApplication = sourceApplicationProvider.currentSourceApplication()
            _ = try repository.saveImage(
                storedImage,
                sourceApp: sourceApplication.name,
                sourceBundleID: sourceApplication.bundleID
            )
            logger.info("Clipboard image saved, bytes: \(storedImage.fileSize)")
            NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
        } catch ImageStorageError.imageTooLarge {
            logger.info("Clipboard image skipped because it exceeds the configured size limit")
        } catch {
            logger.error("Failed to save clipboard image: \(error.localizedDescription)")
        }
    }

    @objc private func handleTimer() {
        pollOnce()
    }
}

extension Notification.Name {
    static let clipboardHistoryDidChange = Notification.Name("clipboardHistoryDidChange")
}
