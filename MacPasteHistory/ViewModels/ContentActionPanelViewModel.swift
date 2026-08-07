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
        registry.sorted.filter {
            commandSearchText.isEmpty || L10n.string($0.titleKey).localizedCaseInsensitiveContains(commandSearchText)
        }
    }
    var availableActions: [any ContentAction] {
        showsRecommendedActions ? recommendedActions.filter { action in
            commandSearchText.isEmpty || L10n.string(action.titleKey).localizedCaseInsensitiveContains(commandSearchText)
        } : allActions
    }
    var recommendedActions: [any ContentAction] {
        guard let session else { return [] }
        return registry.recommended(for: session.sourceItem.effectiveDetectedType)
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
        if session.sourceItem.contentType == .image, session.steps.isEmpty {
            executeImageAction(actionID: actionID, action: action, session: session)
            return
        }
        do {
            let result = try executor.execute(id: actionID, input: session.currentOutput)
            publish(result: result, action: action, actionID: actionID, session: &session)
        } catch let error as ContentActionError {
            state = .failed(error)
        } catch {
            state = .failed(.parseFailed(messageKey: "content-action.failed"))
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
            state = .failed(.unsupportedInput(messageKey: "content-action.unsupported"))
            return
        }
        guard let filePath = session.sourceItem.filePath else {
            state = .failed(.invalidInput(messageKey: "imageMissing"))
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
                state = .failed(error)
            } catch {
                guard Task.isCancelled == false else { return }
                state = .failed(.parseFailed(messageKey: "content-action.failed"))
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
}
