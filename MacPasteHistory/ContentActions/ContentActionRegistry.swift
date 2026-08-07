import Foundation

struct ContentActionRegistry {
    let actions: [any ContentAction]

    init(actions: [any ContentAction] = ContentActionRegistry.defaultActions) { self.actions = actions }

    func action(id: ContentActionID) -> (any ContentAction)? { actions.first { $0.id == id } }
    func recommended(for type: DetectedContentType) -> [any ContentAction] { sorted.filter { $0.supportedTypes.contains(type) } }
    func search(_ query: String) -> [any ContentAction] { sorted.filter { query.isEmpty || $0.titleKey.localizedCaseInsensitiveContains(query) } }
    var sorted: [any ContentAction] { actions.sorted { ($0.category.rawValue, $0.titleKey) < ($1.category.rawValue, $1.titleKey) } }

    static let defaultActions: [any ContentAction] =
        TextContentAction.Kind.allCases.map(TextContentAction.init(kind:)) +
        [JSONContentAction(kind: .format), JSONContentAction(kind: .minify), JSONContentAction(kind: .validate), JSONContentAction(kind: .escape), JSONContentAction(kind: .unescape), URLContentAction(kind: .encodeQueryValue), URLContentAction(kind: .decode), URLContentAction(kind: .extractHost), URLContentAction(kind: .parseQuery), Base64ContentAction(kind: .encode), Base64ContentAction(kind: .decode), Base64ContentAction(kind: .decodeURLSafe), Base64ContentAction(kind: .validate), JWTContentAction(), TimestampContentAction(), SQLContentAction(), ShellContentAction()]
}
