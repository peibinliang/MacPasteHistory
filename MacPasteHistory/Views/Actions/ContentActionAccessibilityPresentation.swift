import Foundation

enum ContentActionAccessibilityPresentation {
    static func actionLabel(_ action: any ContentAction) -> String { L10n.string(action.titleKey) }
    static let actionHint = "Execute selected content action"
    static let resultEditedValue = "Edited result"
    static let derivedLabel = "Derived content"
    static let ocrRecognizingLabel = "Recognizing text"
    static let ocrRecognizedLabel = "Recognized text"
    static let ocrFailedLabel = "Text recognition failed"
    static let jwtSignatureWarning = "JWT signature is not verified."
}
