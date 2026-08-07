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
    @Published private(set) var activeContentType: DetectedContentType = .plainText

    private let registry: ContentActionRegistry
    private let executor: ContentActionExecutor
    private let classifier: ContentClassifier
    private let suitabilityPolicy: ContentActionSuitabilityPolicy
    private var executionTask: Task<Void, Never>?

    init(
        registry: ContentActionRegistry = ContentActionRegistry(),
        executor: ContentActionExecutor? = nil,
        classifier: ContentClassifier = ContentClassifier(),
        suitabilityPolicy: ContentActionSuitabilityPolicy = ContentActionSuitabilityPolicy()
    ) {
        self.registry = registry
        self.executor = executor ?? ContentActionExecutor(registry: registry)
        self.classifier = classifier
        self.suitabilityPolicy = suitabilityPolicy
    }

    var allActions: [any ContentAction] {
        guard let session else { return [] }
        return registry.sorted.filter { isApplicable($0, to: session) }.filter {
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
        return registry.sorted.filter { isApplicable($0, to: session) }
    }
    var failureMessageKey: String? {
        guard case let .failed(error) = state else { return nil }
        return error.messageKey
    }
    var hasUsableResult: Bool {
        state == .previewing && session?.steps.isEmpty == false
    }

    func present(for item: ClipboardHistoryItem, sourceText: String? = nil, recommendedOnly: Bool = false) {
        commandSearchText = ""
        let resolvedSourceText = sourceText ?? item.textContent
        session = ActionSession(sourceItem: item, sourceText: resolvedSourceText)
        activeContentType = detectedType(for: item, sourceText: resolvedSourceText)
        selectedAction = nil
        copyVariants = []
        notices = []
        editedOutput = sourceText ?? item.textContent
        showsRecommendedActions = recommendedOnly
        state = .choosing
    }

    func execute(actionID: ContentActionID) {
        guard var session, let action = registry.action(id: actionID) else { return }
        guard isExecutable(action, in: session) else {
            state = .failed(.unsupportedInput(messageKey: "content-action.unsupported"))
            return
        }
        state = .executing(actionID)
        if session.sourceItem.contentType == .image,
           session.steps.isEmpty,
           action is any BinaryContentAction,
           action.supportedTypes.contains(.image) {
            executeImageAction(actionID: actionID, action: action, session: session)
            return
        }
        do {
            let result = try executor.execute(id: actionID, input: session.currentOutput)
            publish(result: result, action: action, actionID: actionID, session: &session)
        } catch let error as ContentActionError {
            copyVariants = []
            notices = []
            state = .failed(error)
        } catch {
            copyVariants = []
            notices = []
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
        activeContentType = .plainText
        commandSearchText = ""
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
                copyVariants = []
                notices = []
                state = .failed(error)
            } catch {
                guard Task.isCancelled == false else { return }
                copyVariants = []
                notices = []
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

    private func isApplicable(_ action: any ContentAction, to session: ActionSession) -> Bool {
        suitabilityPolicy.isSuitable(action, for: activeContentType)
            && isExecutable(action, in: session)
    }

    private func isExecutable(_ action: any ContentAction, in session: ActionSession) -> Bool {
        if session.sourceItem.contentType == .image, session.sourceText.isEmpty {
            return action.supportedTypes.contains(.image)
        }
        return action.supportedTypes.contains(activeContentType)
    }

    private func detectedType(for item: ClipboardHistoryItem, sourceText: String) -> DetectedContentType {
        if item.contentType == .image, sourceText.isEmpty {
            return .image
        }
        if let userOverrideType = item.userOverrideType {
            return userOverrideType
        }
        return classifier.classifyComplete(sourceText).type
    }
}
