import Foundation

struct ContentActionExecutor {
    let registry: ContentActionRegistry

    init(registry: ContentActionRegistry = ContentActionRegistry()) {
        self.registry = registry
    }

    func execute(id: ContentActionID, input: String) throws -> ContentActionResult {
        guard let action = registry.action(id: id) else {
            throw ContentActionError.unsupportedInput(messageKey: "content-action.unsupported")
        }
        if case let .invalid(error) = action.validate(input: input) { throw error }
        return try action.execute(input: input)
    }

    func execute(id: ContentActionID, fileURL: URL) async throws -> ContentActionResult {
        guard let action = registry.action(id: id) as? any BinaryContentAction else {
            throw ContentActionError.unsupportedInput(messageKey: "content-action.unsupported")
        }
        let data: Data
        do {
            data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: fileURL, options: .mappedIfSafe)
            }.value
        } catch {
            throw ContentActionError.invalidInput(messageKey: "imageMissing")
        }
        return try action.execute(data: data)
    }
}
