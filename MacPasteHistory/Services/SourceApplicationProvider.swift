import AppKit
import Foundation

struct SourceApplication {
    let name: String?
    let bundleID: String?
}

protocol SourceApplicationProviding {
    func currentSourceApplication() -> SourceApplication
}

final class SourceApplicationProvider: SourceApplicationProviding {
    func currentSourceApplication() -> SourceApplication {
        let application = NSWorkspace.shared.frontmostApplication
        return SourceApplication(
            name: application?.localizedName,
            bundleID: application?.bundleIdentifier
        )
    }
}
