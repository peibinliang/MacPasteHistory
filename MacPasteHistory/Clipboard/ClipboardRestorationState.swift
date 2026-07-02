import Foundation

final class ClipboardRestorationState {
    private var shouldSkipNextChange = false

    func markNextChangeShouldBeSkipped() {
        shouldSkipNextChange = true
    }

    func consumeShouldSkipNextChange() -> Bool {
        guard shouldSkipNextChange else {
            return false
        }
        shouldSkipNextChange = false
        return true
    }
}
