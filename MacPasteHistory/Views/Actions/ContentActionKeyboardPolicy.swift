import Foundation

enum ContentActionKeyboardDirection {
    case up
    case down
}

enum ContentActionEscapeTarget: Equatable {
    case closePalette
    case closePreview
    case closePanel
}

enum ContentActionKeyboardPolicy {
    static func moveSelection(
        current: ContentActionID?,
        actions: [ContentActionID],
        direction: ContentActionKeyboardDirection
    ) -> ContentActionID? {
        guard actions.isEmpty == false else { return nil }
        guard let current, let index = actions.firstIndex(of: current) else { return actions[0] }
        switch direction {
        case .up: return actions[(index - 1 + actions.count) % actions.count]
        case .down: return actions[(index + 1) % actions.count]
        }
    }

    static func escapeTarget(for state: ContentActionPanelState) -> ContentActionEscapeTarget {
        switch state {
        case .choosing, .executing: .closePalette
        case .previewing, .failed: .closePreview
        case .closed: .closePanel
        }
    }
}
