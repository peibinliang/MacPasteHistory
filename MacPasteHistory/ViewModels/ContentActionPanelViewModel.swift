import Combine
import Foundation

enum ContentActionPanelState: Equatable {
    case closed
    case choosing
    case executing(ContentActionID)
    case previewing
    case failed(ContentActionError)
}

@MainActor
final class ContentActionPanelViewModel: ObservableObject {
    @Published private(set) var state: ContentActionPanelState = .closed
    @Published var commandSearchText = ""
    @Published private(set) var selectedAction: ContentActionID?
    @Published private(set) var session: ActionSession?
    @Published private(set) var copyVariants: [ContentActionCopyVariant] = []
    @Published private(set) var notices: [ContentActionNotice] = []
    @Published private(set) var editedOutput = ""
    @Published private(set) var showsRecommendedActions = false

    private let registry: ContentActionRegistry
    private let executor: ContentActionExecutor
    private var executionTask: Task<Void, Never>?

    init(registry: ContentActionRegistry = ContentActionRegistry(), executor: ContentActionExecutor? = nil) {
        self.registry = registry
        self.executor = executor ?? ContentActionExecutor(registry: registry)
    }

    var allActions: [any ContentAction] {
        guard let session else { return [] }
        let applicable = registry.sorted.filter { isApplicable($0, to: session) }
        let recommendedIDs = Set(registry.recommended(for: session.sourceItem.effectiveDetectedType).map(\.id))
        return applicable.filter { recommendedIDs.contains($0.id) }
            + applicable.filter { recommendedIDs.contains($0.id) == false }
    }
    var availableActions: [any ContentAction] {
        let candidates = showsRecommendedActions ? recommendedActions : allActions
        return candidates.filter { action in
            commandSearchText.isEmpty || L10n.string(action.titleKey).localizedCaseInsensitiveContains(commandSearchText)
        }
    }
    var recommendedActions: [any ContentAction] {
        guard let session else { return [] }
        return registry.recommended(for: session.sourceItem.effectiveDetectedType)
            .filter { isApplicable($0, to: session) }
    }

    var failureMessageKey: String? {
        guard case let .failed(error) = state else { return nil }
        return error.messageKey
    }

    var hasUsableResult: Bool {
        state == .previewing && session?.steps.isEmpty == false
    }

    func present(for item: ClipboardHistoryItem, sourceText: String? = nil, recommendedOnly: Bool = false) {
        session = ActionSession(sourceItem: item, sourceText: sourceText)
        selectedAction = nil
        copyVariants = []
        notices = []
        editedOutput = sourceText ?? item.textContent
        showsRecommendedActions = recommendedOnly
        state = .choosing
    }

    func execute(actionID: ContentActionID) {
        guard var session, let action = registry.action(id: actionID) else { return }
        state = .executing(actionID)
        if shouldExecuteBinary(action: action, session: session) {
            executeImageAction(actionID: actionID, action: action, session: session)
            return
        }
        do {
            let result = try executor.execute(id: actionID, input: session.currentOutput)
            publish(result: result, action: action, actionID: actionID, session: &session)
        } catch let error as ContentActionError {
            publishFailure(error, actionID: actionID)
        } catch {
            publishFailure(.parseFailed(messageKey: "content-action.failed"), actionID: actionID)
        }
    }

    func updateEditedOutput(_ text: String) {
        guard var session else { return }
        session.updateEditedOutput(text)
        self.session = session
        editedOutput = text
    }

    func moveBack() {
        guard var session else { return }
        session.moveBack()
        self.session = session
        editedOutput = session.currentOutput
        state = .previewing
    }

    func restoreCurrentOutput() {
        guard var session else { return }
        session.restoreCurrentOutput()
        self.session = session
        editedOutput = session.currentOutput
    }

    func close() {
        executionTask?.cancel()
        executionTask = nil
        state = .closed
        session = nil
        selectedAction = nil
        copyVariants = []
        notices = []
        editedOutput = ""
        showsRecommendedActions = false
    }

    private func executeImageAction(
        actionID: ContentActionID,
        action: any ContentAction,
        session: ActionSession
    ) {
        guard action.supportedTypes.contains(.image) else {
            publishFailure(.unsupportedInput(messageKey: "content-action.unsupported"), actionID: actionID)
            return
        }
        guard let filePath = session.sourceItem.filePath else {
            publishFailure(.invalidInput(messageKey: "imageMissing"), actionID: actionID)
            return
        }
        executionTask?.cancel()
        executionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await executor.execute(
                    id: actionID,
                    fileURL: URL(fileURLWithPath: filePath)
                )
                guard Task.isCancelled == false else { return }
                var updatedSession = session
                publish(result: result, action: action, actionID: actionID, session: &updatedSession)
            } catch let error as ContentActionError {
                guard Task.isCancelled == false else { return }
                publishFailure(error, actionID: actionID)
            } catch {
                guard Task.isCancelled == false else { return }
                publishFailure(.parseFailed(messageKey: "content-action.failed"), actionID: actionID)
            }
        }
    }

    private func publish(
        result: ContentActionResult,
        action: any ContentAction,
        actionID: ContentActionID,
        session: inout ActionSession
    ) {
        session.append(action: action, result: result, input: session.currentOutput)
        self.session = session
        selectedAction = actionID
        copyVariants = result.copyVariants
        notices = result.notices
        editedOutput = result.output
        state = .previewing
    }

    private func shouldExecuteBinary(action: any ContentAction, session: ActionSession) -> Bool {
        session.sourceItem.contentType == .image
            && session.steps.isEmpty
            && session.sourceText.isEmpty
            && action.supportedTypes.contains(.image)
    }

    private func isApplicable(_ action: any ContentAction, to session: ActionSession) -> Bool {
        if session.sourceItem.contentType == .image, session.sourceText.isEmpty {
            return action.supportedTypes.contains(.image)
        }
        return action.supportedTypes.contains(session.sourceItem.effectiveDetectedType)
            || action.supportedTypes.contains(.plainText)
    }

    private func publishFailure(_ error: ContentActionError, actionID: ContentActionID) {
        selectedAction = actionID
        copyVariants = []
        notices = []
        editedOutput = ""
        state = .failed(error)
    }
}
