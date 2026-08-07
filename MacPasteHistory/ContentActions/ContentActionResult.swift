import Foundation

struct ContentActionCopyVariant: Identifiable, Equatable, Sendable {
    let id: String
    let titleKey: String
    let value: String
}
struct ContentActionNotice: Equatable, Sendable { let messageKey: String }
struct ContentActionResult: Equatable, Sendable {
    let output: String
    let syntax: ContentSyntax
    let notices: [ContentActionNotice]
    let copyVariants: [ContentActionCopyVariant]
}
