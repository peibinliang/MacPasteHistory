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
    private var privacyService: PrivacyService
    private let logger: Logger
    private let contentClassifier: ContentClassifier
    private let captureQueue = DispatchQueue(
        label: "com.peibin.MacPasteHistory.clipboardCapture",
        qos: .utility
    )
    private let cleanupController: PeriodicCleanupController
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
        privacyService: PrivacyService = PrivacyService(),
        logger: Logger = Logger(category: "ClipboardMonitor"),
        contentClassifier: ContentClassifier = ContentClassifier(),
        periodicCleanupHandler: (@Sendable () -> Void)? = nil,
        periodicCleanupCaptureThreshold: Int = DefaultSettings.periodicCleanupCaptureThreshold,
        periodicCleanupInterval: TimeInterval = DefaultSettings.periodicCleanupInterval,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.pasteboard = pasteboard
        self.reader = reader ?? ClipboardReader(pasteboard: pasteboard)
        self.repository = repository
        self.imageStorageService = imageStorageService
        self.sourceApplicationProvider = sourceApplicationProvider
        self.restorationState = restorationState
        self.recordingSettings = recordingSettings
        self.privacyService = privacyService
        self.logger = logger
        self.contentClassifier = contentClassifier
        self.cleanupController = PeriodicCleanupController(
            handler: periodicCleanupHandler,
            captureThreshold: periodicCleanupCaptureThreshold,
            interval: periodicCleanupInterval,
            nowProvider: nowProvider
        )
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
        guard let preparedCapture = prepareCaptureIfNeeded() else {
            return
        }
        Self.processPreparedCapture(
            preparedCapture,
            repository: repository,
            imageStorageService: imageStorageService,
            contentClassifier: contentClassifier,
            cleanupController: cleanupController,
            logger: logger,
            notifyAsyncOnMain: false
        )
    }

    func performTimerPollForTesting() {
        pollFromTimer()
    }

    func flushPendingCapturesForTesting() {
        captureQueue.sync {}
    }

    private func pollFromTimer() {
        guard let preparedCapture = prepareCaptureIfNeeded() else {
            return
        }
        let repository = self.repository
        let imageStorageService = self.imageStorageService
        let contentClassifier = self.contentClassifier
        let cleanupController = self.cleanupController
        let logger = self.logger

        captureQueue.async {
            Self.processPreparedCapture(
                preparedCapture,
                repository: repository,
                imageStorageService: imageStorageService,
                contentClassifier: contentClassifier,
                cleanupController: cleanupController,
                logger: logger,
                notifyAsyncOnMain: true
            )
        }
    }

    private func prepareCaptureIfNeeded() -> PreparedClipboardCapture? {
        guard pasteboard.changeCount != lastChangeCount else {
            return nil
        }
        lastChangeCount = pasteboard.changeCount

        guard restorationState.consumeShouldSkipNextChange() == false else {
            logger.info("Skipped internally restored clipboard change")
            return nil
        }

        // Privacy: skip if recording is paused
        guard privacyService.recordingPaused == false else {
            return nil
        }

        // Privacy: skip if the current foreground app is blocked
        let captureContext = ClipboardCaptureContext(
            sourceApplication: sourceApplicationProvider.currentSourceApplication(),
            capturedAt: Date()
        )
        if privacyService.isAppBlocked(bundleID: captureContext.sourceApplication.bundleID) {
            logger.info(
                "Skipped clipboard change from blocked app: "
                    + (captureContext.sourceApplication.bundleID ?? "unknown")
            )
            return nil
        }

        let shouldRecordImage = recordingSettings.shouldRecordImage
        let shouldRecordText = recordingSettings.shouldRecordText
        guard shouldRecordImage || shouldRecordText else {
            return nil
        }

        let snapshot = reader.readRawSnapshot(
            shouldRecordImage: shouldRecordImage,
            shouldRecordText: shouldRecordText
        )
        guard snapshot.imageSource != nil || snapshot.rawText != nil else {
            return nil
        }

        return PreparedClipboardCapture(
            snapshot: snapshot,
            context: captureContext,
            shouldRecordText: shouldRecordText,
            isSensitiveFilteringEnabled: privacyService.isSensitiveFilteringEnabled
        )
    }

    private static func processPreparedCapture(
        _ capture: PreparedClipboardCapture,
        repository: ClipboardHistoryRepository,
        imageStorageService: ImageStorageService,
        contentClassifier: ContentClassifier,
        cleanupController: PeriodicCleanupController,
        logger: Logger,
        notifyAsyncOnMain: Bool
    ) {
        if let imageSource = capture.snapshot.imageSource,
           let candidate = ClipboardReader.decodeImageCandidate(from: imageSource) {
            saveImage(
                candidate,
                context: capture.context,
                repository: repository,
                imageStorageService: imageStorageService,
                cleanupController: cleanupController,
                logger: logger,
                notifyAsyncOnMain: notifyAsyncOnMain
            )
            return
        }

        guard capture.shouldRecordText,
              let rawText = capture.snapshot.rawText,
              let text = ClipboardReader.sanitizePlainText(rawText) else {
            return
        }

        if capture.isSensitiveFilteringEnabled,
           SensitiveContentDetector.detect(text).shouldBlockPersistence {
            logger.info("Skipped sensitive clipboard content")
            return
        }

        saveText(
            text,
            context: capture.context,
            repository: repository,
            contentClassifier: contentClassifier,
            cleanupController: cleanupController,
            logger: logger,
            notifyAsyncOnMain: notifyAsyncOnMain
        )
    }

    private static func saveText(
        _ text: String,
        context: ClipboardCaptureContext,
        repository: ClipboardHistoryRepository,
        contentClassifier: ContentClassifier,
        cleanupController: PeriodicCleanupController,
        logger: Logger,
        notifyAsyncOnMain: Bool
    ) {
        do {
            _ = try repository.saveText(
                text,
                sourceApp: context.sourceApplication.name,
                sourceBundleID: context.sourceApplication.bundleID,
                detection: contentClassifier.classifyComplete(text),
                capturedAt: context.capturedAt
            )
            logger.info("Clipboard text saved, length: \(text.count)")
            cleanupController.recordCaptureAndRunIfNeeded()
            postHistoryDidChange(asyncOnMain: notifyAsyncOnMain)
        } catch {
            logger.error("Failed to save clipboard text: \(error.localizedDescription)")
        }
    }

    private static func saveImage(
        _ image: ClipboardImageCandidate,
        context: ClipboardCaptureContext,
        repository: ClipboardHistoryRepository,
        imageStorageService: ImageStorageService,
        cleanupController: PeriodicCleanupController,
        logger: Logger,
        notifyAsyncOnMain: Bool
    ) {
        do {
            let storedImage = try imageStorageService.storeImage(image)
            _ = try repository.saveImage(
                storedImage,
                sourceApp: context.sourceApplication.name,
                sourceBundleID: context.sourceApplication.bundleID,
                capturedAt: context.capturedAt
            )
            logger.info("Clipboard image saved, bytes: \(storedImage.fileSize)")
            cleanupController.recordCaptureAndRunIfNeeded()
            postHistoryDidChange(asyncOnMain: notifyAsyncOnMain)
        } catch ImageStorageError.imageTooLarge {
            logger.info("Clipboard image skipped because it exceeds the configured size limit")
        } catch {
            logger.error("Failed to save clipboard image: \(error.localizedDescription)")
        }
    }

    private static func postHistoryDidChange(asyncOnMain: Bool) {
        if asyncOnMain {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: .clipboardHistoryDidChange, object: nil)
        }
    }

    @objc private func handleTimer() {
        pollFromTimer()
    }
}

private struct PreparedClipboardCapture: Sendable {
    let snapshot: RawClipboardSnapshot
    let context: ClipboardCaptureContext
    let shouldRecordText: Bool
    let isSensitiveFilteringEnabled: Bool
}

private final class PeriodicCleanupController: @unchecked Sendable {
    private let handler: (@Sendable () -> Void)?
    private let captureThreshold: Int
    private let interval: TimeInterval
    private let nowProvider: @Sendable () -> Date
    private let lock = NSLock()
    private var capturesSinceLastCleanup = 0
    private var lastCleanupDate: Date

    init(
        handler: (@Sendable () -> Void)?,
        captureThreshold: Int,
        interval: TimeInterval,
        nowProvider: @escaping @Sendable () -> Date
    ) {
        self.handler = handler
        self.captureThreshold = max(1, captureThreshold)
        self.interval = max(1, interval)
        self.nowProvider = nowProvider
        self.lastCleanupDate = nowProvider()
    }

    func recordCaptureAndRunIfNeeded() {
        guard let handler else {
            return
        }
        let shouldRun: Bool = {
            lock.lock()
            defer { lock.unlock() }
            capturesSinceLastCleanup += 1
            let now = nowProvider()
            if capturesSinceLastCleanup >= captureThreshold
                || now.timeIntervalSince(lastCleanupDate) >= interval {
                capturesSinceLastCleanup = 0
                lastCleanupDate = now
                return true
            }
            return false
        }()

        if shouldRun {
            handler()
        }
    }
}

extension Notification.Name {
    static let clipboardHistoryDidChange = Notification.Name("clipboardHistoryDidChange")
}
