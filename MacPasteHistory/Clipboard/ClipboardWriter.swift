import AppKit
import Foundation

final class ClipboardWriter {
    private let pasteboard: PasteboardProviding
    private let restorationState: ClipboardRestorationState

    init(pasteboard: PasteboardProviding = NSPasteboard.general, restorationState: ClipboardRestorationState) {
        self.pasteboard = pasteboard
        self.restorationState = restorationState
    }

    func writeText(_ text: String) -> Bool {
        _ = pasteboard.clearContents()
        let didWrite = pasteboard.setString(text, forType: .string)
        if didWrite {
            restorationState.markNextChangeShouldBeSkipped()
        }
        return didWrite
    }

    func writeImage(_ pngData: Data) -> Bool {
        _ = pasteboard.clearContents()
        let didWrite = pasteboard.setData(pngData, forType: .png)
        if didWrite {
            restorationState.markNextChangeShouldBeSkipped()
        }
        return didWrite
    }
}
