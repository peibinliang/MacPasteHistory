import Foundation

struct ActionSession: Equatable {
    let sourceItem: ClipboardHistoryItem
    let sourceText: String
    private(set) var steps: [ActionSessionStep] = []
    private(set) var currentIndex: Int?

    init(sourceItem: ClipboardHistoryItem, sourceText: String? = nil) {
        self.sourceItem = sourceItem
        self.sourceText = sourceText ?? sourceItem.textContent
    }

    mutating func append(action: any ContentAction, result: ContentActionResult, input: String) {
        let retainedStepCount = currentIndex.map { $0 + 1 } ?? 0
        steps.removeSubrange(retainedStepCount..<steps.count)
        let step = ActionSessionStep(id: UUID(), actionID: action.id, actionTitleKey: action.titleKey, input: input, originalResult: result, editedOutput: result.output, error: nil)
        steps.append(step)
        currentIndex = steps.index(before: steps.endIndex)
    }

    mutating func updateEditedOutput(_ text: String) {
        guard let currentIndex else { return }
        steps[currentIndex].editedOutput = text
    }

    mutating func restoreCurrentOutput() {
        guard let currentIndex else { return }
        steps[currentIndex].editedOutput = steps[currentIndex].originalResult.output
    }

    mutating func moveBack() {
        guard let currentIndex else { return }
        self.currentIndex = currentIndex > 0 ? currentIndex - 1 : nil
    }

    mutating func clear() {
        steps.removeAll()
        currentIndex = nil
    }

    var currentOutput: String {
        guard let currentIndex else { return sourceText }
        return steps[currentIndex].editedOutput
    }

    var actionSummary: String {
        steps.map(\.actionTitleKey).joined(separator: " → ")
    }
}
