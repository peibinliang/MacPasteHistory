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

    func present(for item: ClipboardHistoryItem, recommendedOnly: Bool = false) {
        session = ActionSession(sourceItem: item)
        selectedAction = nil
        copyVariants = []
        notices = []
        editedOutput = item.textContent
        showsRecommendedActions = recommendedOnly
        state = .choosing
    }

    func execute(actionID: ContentActionID) {
        guard var session, let action = registry.action(id: actionID) else { return }
        state = .executing(actionID)
        do {
            let result = try executor.execute(id: actionID, input: session.currentOutput)
            session.append(action: action, result: result, input: session.currentOutput)
            self.session = session
            selectedAction = actionID
            copyVariants = result.copyVariants
            notices = result.notices
            editedOutput = result.output
            state = .previewing
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
        state = .closed
        session = nil
        selectedAction = nil
        copyVariants = []
        notices = []
        editedOutput = ""
        showsRecommendedActions = false
    }
}
