import Foundation
import XCTest
@testable import MacPasteHistory

@MainActor
final class PasteCoordinatorTests: XCTestCase {
    func testPasteHistoryText_whenAutomaticPasteIsDisabled_shouldWriteClipboardAndRecordReuseOnce() async {
        let fixture = makeFixture(readiness: .clipboardOnly)

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("history text"), historyID: 101)
        )

        XCTAssertEqual(outcome, .clipboardOnly(.automaticPasteDisabled))
        XCTAssertEqual(fixture.writer.textWrites, ["history text"])
        XCTAssertEqual(fixture.usageRecorder.reuseIDs, [101])
        XCTAssertTrue(fixture.usageRecorder.pasteIDs.isEmpty)
        XCTAssertEqual(fixture.commandDispatcher.callCount, 0)
    }

    func testPasteHistoryImage_whenPermissionIsMissing_shouldWriteClipboardAndRequirePermission() async {
        let fixture = makeFixture(readiness: .permissionRequired)
        let imageData = Data([1, 2, 3])

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .image(imageData), historyID: 102)
        )

        XCTAssertEqual(outcome, .permissionRequired)
        XCTAssertEqual(fixture.writer.imageWrites, [imageData])
        XCTAssertEqual(fixture.usageRecorder.reuseIDs, [102])
        XCTAssertTrue(fixture.usageRecorder.pasteIDs.isEmpty)
    }

    func testPasteActionOutput_whenTargetIsMissing_shouldFallBackWithoutDispatch() async {
        let fixture = makeFixture(readiness: .ready, target: nil)

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("action output"), historyID: 103)
        )

        XCTAssertEqual(outcome, .clipboardOnly(.targetUnavailable))
        XCTAssertEqual(fixture.writer.textWrites, ["action output"])
        XCTAssertEqual(fixture.usageRecorder.reuseIDs, [103])
        XCTAssertEqual(fixture.commandDispatcher.callCount, 0)
    }

    func testPasteActionOutput_whenDispatchSucceeds_shouldActivateAndRecordPasteOnly() async {
        let target = StubPasteTarget(didActivate: true)
        let fixture = makeFixture(readiness: .ready, target: target, didDispatch: true)

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("action output"), historyID: 104)
        )

        XCTAssertEqual(outcome, .pasted)
        XCTAssertEqual(target.activationCount, 1)
        XCTAssertEqual(fixture.commandDispatcher.callCount, 1)
        XCTAssertEqual(fixture.usageRecorder.pasteIDs, [104])
        XCTAssertTrue(fixture.usageRecorder.reuseIDs.isEmpty)
    }

    func testPaste_whenCommandDispatchFails_shouldKeepClipboardAndRecordReuseOnly() async {
        let fixture = makeFixture(
            readiness: .ready,
            target: StubPasteTarget(didActivate: true),
            didDispatch: false
        )

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("manual fallback"), historyID: 105)
        )

        XCTAssertEqual(outcome, .clipboardOnly(.commandFailed))
        XCTAssertEqual(fixture.usageRecorder.reuseIDs, [105])
        XCTAssertTrue(fixture.usageRecorder.pasteIDs.isEmpty)
    }

    func testPaste_whenClipboardWriteFails_shouldNotActivateDispatchOrRecordUsage() async {
        let writer = StubClipboardContentWriter(shouldWrite: false)
        let target = StubPasteTarget(didActivate: true)
        let fixture = makeFixture(readiness: .ready, writer: writer, target: target)

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("unwritable"), historyID: 106)
        )

        XCTAssertEqual(outcome, .failed(.clipboardWrite))
        XCTAssertEqual(target.activationCount, 0)
        XCTAssertEqual(fixture.commandDispatcher.callCount, 0)
        XCTAssertTrue(fixture.usageRecorder.reuseIDs.isEmpty)
        XCTAssertTrue(fixture.usageRecorder.pasteIDs.isEmpty)
    }

    func testPaste_whenCancelledAfterClipboardWrite_shouldRecordClipboardOnlyOnce() async {
        let delay = ControlledPasteDispatchDelay()
        let fixture = makeFixture(
            readiness: .ready,
            target: StubPasteTarget(didActivate: true),
            dispatchDelay: delay
        )
        let task = Task {
            await fixture.coordinator.paste(
                PasteRequest(payload: .text("cancelled paste"), historyID: 107)
            )
        }
        await delay.waitUntilStarted()

        task.cancel()
        let outcome = await task.value

        XCTAssertEqual(outcome, .cancelled(clipboardAvailable: true))
        XCTAssertEqual(fixture.usageRecorder.reuseIDs, [107])
        XCTAssertTrue(fixture.usageRecorder.pasteIDs.isEmpty)
        XCTAssertEqual(fixture.commandDispatcher.callCount, 0)
    }

    func testPaste_whenUsageAccountingFails_shouldReturnTypedFailureWithoutDoubleCounting() async {
        let usageRecorder = StubPasteUsageRecorder(shouldFail: true)
        let fixture = makeFixture(
            readiness: .clipboardOnly,
            usageRecorder: usageRecorder
        )

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("accounting failure"), historyID: 108)
        )

        XCTAssertEqual(outcome, .failed(.usageAccounting))
        XCTAssertEqual(usageRecorder.reuseAttempts, [108])
        XCTAssertTrue(usageRecorder.pasteAttempts.isEmpty)
    }

    func testPaste_whenReady_shouldPrepareUIOnceBeforeTargetActivation() async {
        var preparationCount = 0
        let target = StubPasteTarget(didActivate: true)
        let fixture = makeFixture(readiness: .ready, target: target)

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("prepared paste"), historyID: 109)
        ) {
            preparationCount += 1
        }

        XCTAssertEqual(outcome, .pasted)
        XCTAssertEqual(preparationCount, 1)
        XCTAssertEqual(target.activationCount, 1)
    }

    func testPaste_whenClipboardOnly_shouldNotPrepareUIForDispatch() async {
        var preparationCount = 0
        let fixture = makeFixture(readiness: .clipboardOnly)

        let outcome = await fixture.coordinator.paste(
            PasteRequest(payload: .text("manual paste"), historyID: 110)
        ) {
            preparationCount += 1
        }

        XCTAssertEqual(outcome, .clipboardOnly(.automaticPasteDisabled))
        XCTAssertEqual(preparationCount, 0)
    }

    private func makeFixture(
        readiness: AutomaticPasteReadiness,
        writer: StubClipboardContentWriter = StubClipboardContentWriter(),
        target: StubPasteTarget? = StubPasteTarget(didActivate: true),
        didDispatch: Bool = true,
        usageRecorder: StubPasteUsageRecorder = StubPasteUsageRecorder(),
        dispatchDelay: any PasteDispatchDelaying = ImmediatePasteDispatchDelay()
    ) -> PasteCoordinatorFixture {
        let readinessProvider = StubAutomaticPasteReadinessProvider(readiness: readiness)
        let commandDispatcher = StubPasteCommandDispatcher(didDispatch: didDispatch)
        let coordinator = PasteCoordinator(
            writer: writer,
            readinessProvider: readinessProvider,
            target: target,
            commandDispatcher: commandDispatcher,
            usageRecorder: usageRecorder,
            dispatchDelay: dispatchDelay
        )
        return PasteCoordinatorFixture(
            coordinator: coordinator,
            writer: writer,
            commandDispatcher: commandDispatcher,
            usageRecorder: usageRecorder
        )
    }
}

@MainActor
private struct PasteCoordinatorFixture {
    let coordinator: PasteCoordinator
    let writer: StubClipboardContentWriter
    let commandDispatcher: StubPasteCommandDispatcher
    let usageRecorder: StubPasteUsageRecorder
}

private final class StubClipboardContentWriter: ClipboardContentWriting {
    private let shouldWrite: Bool
    private(set) var textWrites: [String] = []
    private(set) var imageWrites: [Data] = []

    init(shouldWrite: Bool = true) {
        self.shouldWrite = shouldWrite
    }

    func writeText(_ text: String) -> Bool {
        textWrites.append(text)
        return shouldWrite
    }

    func writeImage(_ data: Data) -> Bool {
        imageWrites.append(data)
        return shouldWrite
    }
}

private struct StubAutomaticPasteReadinessProvider: AutomaticPasteReadinessProviding {
    let readiness: AutomaticPasteReadiness
}

private final class StubPasteTarget: PasteTargetActivating {
    private let didActivate: Bool
    private(set) var activationCount = 0

    init(didActivate: Bool) {
        self.didActivate = didActivate
    }

    func activateForPaste() -> Bool {
        activationCount += 1
        return didActivate
    }
}

private final class StubPasteCommandDispatcher: PasteCommandDispatching {
    private let didDispatch: Bool
    private(set) var callCount = 0

    init(didDispatch: Bool) {
        self.didDispatch = didDispatch
    }

    func sendPasteCommand() -> Bool {
        callCount += 1
        return didDispatch
    }
}

private final class StubPasteUsageRecorder: PasteUsageRecording {
    private let shouldFail: Bool
    private(set) var reuseAttempts: [Int64] = []
    private(set) var pasteAttempts: [Int64] = []
    private(set) var reuseIDs: [Int64] = []
    private(set) var pasteIDs: [Int64] = []

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func recordReuseCopy(historyID: Int64, at date: Date) throws {
        reuseAttempts.append(historyID)
        guard shouldFail == false else { throw PasteCoordinatorTestError.accountingFailure }
        reuseIDs.append(historyID)
    }

    func recordPaste(historyID: Int64, at date: Date) throws {
        pasteAttempts.append(historyID)
        guard shouldFail == false else { throw PasteCoordinatorTestError.accountingFailure }
        pasteIDs.append(historyID)
    }
}

private struct ImmediatePasteDispatchDelay: PasteDispatchDelaying {
    func wait() async throws {}
}

private actor ControlledPasteDispatchDelay: PasteDispatchDelaying {
    private var started = false

    func wait() async throws {
        started = true
        while true {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    func waitUntilStarted() async {
        while started == false {
            await Task.yield()
        }
    }
}

private enum PasteCoordinatorTestError: Error {
    case accountingFailure
}
