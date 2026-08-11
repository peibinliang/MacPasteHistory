import SwiftUI

@main
struct MacPasteHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                viewModel: appDelegate.makeSettingsViewModel(),
                updateService: appDelegate.makeUpdateService()
            )
        }
    }
}
