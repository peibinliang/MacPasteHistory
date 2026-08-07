import Foundation

struct ContentActionID: RawRepresentable, Hashable, Codable, Comparable, Sendable {
    let rawValue: String
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum ContentSyntax: Equatable, Sendable { case plainText, json, sql, jwt }
enum ContentActionCategory: String, CaseIterable, Sendable { case json, url, base64, text }
enum ContentActionError: Error, Equatable, Sendable {
    case invalidInput(messageKey: String), unsupportedInput(messageKey: String), parseFailed(messageKey: String), decodeFailed(messageKey: String), nonUTF8Result(messageKey: String), outOfRange(messageKey: String), emptyResult(messageKey: String)
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
