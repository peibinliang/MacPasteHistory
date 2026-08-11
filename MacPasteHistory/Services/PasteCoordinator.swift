import AppKit
import Foundation

@MainActor
protocol ClipboardContentWriting: AnyObject {
    func writeText(_ text: String) -> Bool
    func writeImage(_ data: Data) -> Bool
}

@MainActor
protocol AutomaticPasteReadinessProviding {
    var readiness: AutomaticPasteReadiness { get }
}

@MainActor
protocol PasteTargetActivating: AnyObject {
    func activateForPaste() -> Bool
}

@MainActor
protocol PasteCommandDispatching: AnyObject {
    func sendPasteCommand() -> Bool
}

@MainActor
protocol PasteUsageRecording: AnyObject {
    func recordReuseCopy(historyID: Int64, at date: Date) throws
    func recordPaste(historyID: Int64, at date: Date) throws
}

protocol PasteDispatchDelaying: Sendable {
    func wait() async throws
}

struct DefaultPasteDispatchDelay: PasteDispatchDelaying {
    func wait() async throws {
        try await Task.sleep(for: .milliseconds(250))
    }
}

@MainActor
final class PasteCoordinator {
    private let writer: any ClipboardContentWriting
    private let readinessProvider: any AutomaticPasteReadinessProviding
    private let target: (any PasteTargetActivating)?
    private let commandDispatcher: any PasteCommandDispatching
    private let usageRecorder: any PasteUsageRecording
    private let dispatchDelay: any PasteDispatchDelaying
    private let now: () -> Date

    init(
        writer: any ClipboardContentWriting,
        readinessProvider: any AutomaticPasteReadinessProviding,
        target: (any PasteTargetActivating)?,
        commandDispatcher: any PasteCommandDispatching,
        usageRecorder: any PasteUsageRecording,
        dispatchDelay: any PasteDispatchDelaying = DefaultPasteDispatchDelay(),
        now: @escaping () -> Date = Date.init
    ) {
        self.writer = writer
        self.readinessProvider = readinessProvider
        self.target = target
        self.commandDispatcher = commandDispatcher
        self.usageRecorder = usageRecorder
        self.dispatchDelay = dispatchDelay
        self.now = now
    }

    func paste(
        _ request: PasteRequest,
        beforeDispatch: (() -> Void)? = nil
    ) async -> PasteOutcome {
        guard Task.isCancelled == false else {
            return .cancelled(clipboardAvailable: false)
        }
        guard write(request.payload) else {
            return .failed(.clipboardWrite)
        }

        switch readinessProvider.readiness {
        case .clipboardOnly:
            return recordClipboardOnly(request.historyID, outcome: .clipboardOnly(.automaticPasteDisabled))
        case .permissionRequired:
            return recordClipboardOnly(request.historyID, outcome: .permissionRequired)
        case .ready:
            return await dispatchPaste(request, beforeDispatch: beforeDispatch)
        }
    }

    private func dispatchPaste(_ request: PasteRequest, beforeDispatch: (() -> Void)?) async -> PasteOutcome {
        guard Task.isCancelled == false else {
            return recordClipboardOnly(
                request.historyID,
                outcome: .cancelled(clipboardAvailable: true)
            )
        }
        guard let target else {
            return recordClipboardOnly(request.historyID, outcome: .clipboardOnly(.targetUnavailable))
        }
        beforeDispatch?()
        guard target.activateForPaste() else {
            return recordClipboardOnly(request.historyID, outcome: .clipboardOnly(.targetUnavailable))
        }

        do {
            try await dispatchDelay.wait()
        } catch is CancellationError {
            return recordClipboardOnly(
                request.historyID,
                outcome: .cancelled(clipboardAvailable: true)
            )
        } catch {
            return recordClipboardOnly(request.historyID, outcome: .failed(.dispatchPreparation))
        }
        guard Task.isCancelled == false else {
            return recordClipboardOnly(
                request.historyID,
                outcome: .cancelled(clipboardAvailable: true)
            )
        }
        guard commandDispatcher.sendPasteCommand() else {
            return recordClipboardOnly(request.historyID, outcome: .clipboardOnly(.commandFailed))
        }

        do {
            try usageRecorder.recordPaste(historyID: request.historyID, at: now())
            return .pasted
        } catch {
            return .failed(.usageAccounting)
        }
    }

    private func write(_ payload: PastePayload) -> Bool {
        switch payload {
        case let .text(text):
            return writer.writeText(text)
        case let .image(data):
            return writer.writeImage(data)
        }
    }

    private func recordClipboardOnly(_ historyID: Int64, outcome: PasteOutcome) -> PasteOutcome {
        do {
            try usageRecorder.recordReuseCopy(historyID: historyID, at: now())
            return outcome
        } catch {
            return .failed(.usageAccounting)
        }
    }
}

extension ClipboardWriter: ClipboardContentWriting {}
extension AutomaticPastePolicy: AutomaticPasteReadinessProviding {}
extension PasteCommandService: PasteCommandDispatching {}
extension ClipboardHistoryRepository: PasteUsageRecording {}

@MainActor
final class RunningApplicationPasteTarget: PasteTargetActivating {
    private let application: NSRunningApplication

    init(application: NSRunningApplication) {
        self.application = application
    }

    func activateForPaste() -> Bool {
        application.activate(options: PasteActivationPolicy.options)
    }
}
