import Foundation

struct ContentActionID: RawRepresentable, Hashable, Codable, Comparable, Sendable {
    let rawValue: String
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum ContentSyntax: Equatable, Sendable { case plainText, json, sql, jwt }
enum ContentActionCategory: String, CaseIterable, Sendable { case json, url, base64, text }
enum ContentActionError: Error, Equatable, Sendable {
    case invalidInput(messageKey: String), unsupportedInput(messageKey: String), parseFailed(messageKey: String), decodeFailed(messageKey: String), nonUTF8Result(messageKey: String), outOfRange(messageKey: String), emptyResult(messageKey: String)

    var messageKey: String {
        switch self {
        case let .invalidInput(messageKey), let .unsupportedInput(messageKey), let .parseFailed(messageKey),
             let .decodeFailed(messageKey), let .nonUTF8Result(messageKey), let .outOfRange(messageKey),
             let .emptyResult(messageKey):
            messageKey
        }
    }
}

enum ActionValidationResult: Equatable, Sendable { case valid, invalid(ContentActionError) }

protocol ContentAction: Sendable {
    var id: ContentActionID { get }
    var titleKey: String { get }
    var category: ContentActionCategory { get }
    var supportedTypes: Set<DetectedContentType> { get }
    func validate(input: String) -> ActionValidationResult
    func execute(input: String) throws -> ContentActionResult
}

protocol BinaryContentAction: ContentAction {
    func execute(data: Data) throws -> ContentActionResult
}

/// Opt-in capability for actions that perform cancellable asynchronous work.
/// Existing local actions intentionally remain synchronous.
protocol AsyncContentAction: ContentAction {
    func executeAsync(input: String) async throws -> ContentActionResult
}

/// Marks actions that transmit their input to a remote AI provider and therefore require disclosure.
protocol RemoteAIContentAction: AsyncContentAction {}
