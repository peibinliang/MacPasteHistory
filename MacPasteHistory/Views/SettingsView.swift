import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            recordingSection
            privacySection
            shortcutSection
            retentionSection
            limitsSection
            storageSection
            languageSection
            dataSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 460, minHeight: 480)
        .onAppear { viewModel.loadSettings() }
        .alert(L10n.string("Clear All Data?"), isPresented: $showClearConfirmation) {
            Button(L10n.string("Cancel"), role: .cancel) {}
            Button(L10n.string("Clear"), role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text(L10n.string("This will permanently delete all clipboard history records and image files. This action cannot be undone."))
        }
        .alert(
            L10n.string("Launch at Login Failed"),
            isPresented: Binding(
                get: { viewModel.launchAtStartupErrorMessage != nil || viewModel.appPreferenceMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.launchAtStartupErrorMessage = nil
                        viewModel.appPreferenceMessage = nil
                    }
                }
            )
        ) {
            Button(L10n.string("OK"), role: .cancel) {}
        } message: {
            Text(viewModel.launchAtStartupErrorMessage ?? viewModel.appPreferenceMessage ?? "")
        }
        .alert(
            L10n.string("Restart Required"),
            isPresented: $viewModel.showRestartAlert
        ) {
            Button(L10n.string("Restart Now")) {
                restartApp()
            }
            Button(L10n.string("Later"), role: .cancel) {}
        } message: {
            Text(L10n.string("The app needs to restart to apply the new language. Would you like to restart now?"))
        }
    }

    // MARK: - Sections

    private var recordingSection: some View {
        Section(L10n.string("Recording")) {
            Toggle(L10n.string("Record text clipboard history"), isOn: $viewModel.shouldRecordText)
                .onChange(of: viewModel.shouldRecordText) { _, newValue in
                    viewModel.updateShouldRecordText(newValue)
                }
            Toggle(L10n.string("Record image clipboard history"), isOn: $viewModel.shouldRecordImage)
                .onChange(of: viewModel.shouldRecordImage) { _, newValue in
                    viewModel.updateShouldRecordImage(newValue)
                }
            Toggle(L10n.string("Launch at login"), isOn: $viewModel.launchAtStartup)
                .onChange(of: viewModel.launchAtStartup) { _, newValue in
                    viewModel.updateLaunchAtStartup(newValue)
                }
            Toggle(L10n.string("Show Dock icon"), isOn: $viewModel.showDockIcon)
                .onChange(of: viewModel.showDockIcon) { _, newValue in
                    viewModel.updateShowDockIcon(newValue)
                }
        }
    }

    private var privacySection: some View {
        Section(L10n.string("Privacy Controls")) {
            Toggle(L10n.string("Pause recording"), isOn: $viewModel.recordingPaused)
                .onChange(of: viewModel.recordingPaused) { _, newValue in
                    viewModel.updateRecordingPaused(newValue)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField(L10n.string("Bundle ID"), text: $viewModel.blockedAppBundleID)
                    TextField(L10n.string("App name"), text: $viewModel.blockedAppDisplayName)
                    Button {
                        viewModel.addBlockedAppFromFields()
                    } label: {
                        Label(L10n.string("Add"), systemImage: "plus")
                    }
                }
                HStack {
                    Button {
                        viewModel.addCurrentForegroundAppToBlockedApps()
                    } label: {
                        Label(L10n.string("Block Current App"), systemImage: "app.badge")
                    }
                    if let message = viewModel.blockedAppErrorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                if viewModel.blockedApps.isEmpty {
                    Text(L10n.string("No blocked apps"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.blockedApps) { entry in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { entry.isEnabled },
                                set: { viewModel.setBlockedAppEnabled(entry, isEnabled: $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.displayName)
                                    Text(entry.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeBlockedApp(entry)
                            } label: {
                                Label(L10n.string("Remove"), systemImage: "minus.circle")
                            }
                            .labelStyle(.iconOnly)
                            .help(L10n.string("Remove"))
                        }
                    }
                }
            }
        }
    }

    private var shortcutSection: some View {
        Section(L10n.string("Keyboard Shortcut")) {
            HStack {
                Text(L10n.string("Open history"))
                Spacer()
                ShortcutRecorderView(shortcut: $viewModel.shortcutConfiguration) { shortcut in
                    viewModel.updateShortcut(shortcut)
                }
                Button {
                    viewModel.resetShortcut()
                } label: {
                    Label(L10n.string("Reset"), systemImage: "arrow.counterclockwise")
                }
            }
            if let message = viewModel.shortcutMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var retentionSection: some View {
        Section(L10n.string("History Retention")) {
            Stepper(
                String(format: L10n.string("Keep history for %lld days"), viewModel.historyRetentionDays),
                value: $viewModel.historyRetentionDays,
                in: 1...365
            )
            .onChange(of: viewModel.historyRetentionDays) { _, newValue in
                viewModel.updateHistoryRetentionDays(newValue)
            }
        }
    }

    private var limitsSection: some View {
        Section(L10n.string("Record Limits")) {
            Stepper(
                String(format: L10n.string("Maximum %lld text records"), viewModel.maxTextHistoryCount),
                value: $viewModel.maxTextHistoryCount,
                in: 100...5_000,
                step: 100
            )
            .onChange(of: viewModel.maxTextHistoryCount) { _, newValue in
                viewModel.updateMaxTextHistoryCount(newValue)
            }
            Stepper(
                String(format: L10n.string("Maximum %lld image records"), viewModel.maxImageHistoryCount),
                value: $viewModel.maxImageHistoryCount,
                in: 10...500,
                step: 10
            )
            .onChange(of: viewModel.maxImageHistoryCount) { _, newValue in
                viewModel.updateMaxImageHistoryCount(newValue)
            }
        }
    }

    private var storageSection: some View {
        Section(L10n.string("Storage")) {
            Picker(L10n.string("Single image size limit"), selection: $viewModel.singleImageSizeLimit) {
                Text("5 MB").tag(5)
                Text("10 MB").tag(10)
                Text("20 MB").tag(20)
                Text("50 MB").tag(50)
            }
            .onChange(of: viewModel.singleImageSizeLimit) { _, newValue in
                viewModel.updateSingleImageSizeLimit(newValue)
            }
            Picker(L10n.string("Total storage cap"), selection: $viewModel.totalStorageCap) {
                Text("100 MB").tag(100)
                Text("250 MB").tag(250)
                Text("500 MB").tag(500)
                Text("1 GB").tag(1_000)
            }
            .onChange(of: viewModel.totalStorageCap) { _, newValue in
                viewModel.updateTotalStorageCap(newValue)
            }
        }
    }

    private var languageSection: some View {
        Section(L10n.string("Language")) {
            Picker(L10n.string("Language"), selection: $viewModel.selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .onChange(of: viewModel.selectedLanguage) { _, newValue in
                viewModel.updateLanguage(newValue)
            }
        }
    }

    private var dataSection: some View {
        Section(L10n.string("Data Management")) {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label(L10n.string("Clear All Data"), systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    private func restartApp() {
        AppRelauncher().relaunchAfterTermination(bundlePath: Bundle.main.bundlePath)
        NSApp.terminate(nil)
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: ShortcutConfiguration
    let onShortcutChange: (ShortcutConfiguration) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let view = ShortcutRecorderButton()
        view.onShortcutChange = { shortcut in
            self.shortcut = shortcut
            self.onShortcutChange(shortcut)
        }
        view.shortcut = shortcut
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
    }
}

private final class ShortcutRecorderButton: NSButton {
    var shortcut: ShortcutConfiguration = .default {
        didSet {
            title = shortcut.displayLabel
        }
    }
    var onShortcutChange: ((ShortcutConfiguration) -> Void)?

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        title = shortcut.displayLabel
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    @objc private func beginRecording() {
        window?.makeFirstResponder(self)
        title = L10n.string("Press shortcut")
    }

    override func keyDown(with event: NSEvent) {
        let configuration = ShortcutConfiguration(
            keyCode: UInt32(event.keyCode),
            modifiers: event.modifierFlags.carbonShortcutModifiers
        )
        shortcut = configuration
        onShortcutChange?(configuration)
    }
}

private extension NSEvent.ModifierFlags {
    var carbonShortcutModifiers: UInt32 {
        var result: UInt32 = 0
        if contains(.command) { result |= UInt32(cmdKey) }
        if contains(.shift) { result |= UInt32(shiftKey) }
        if contains(.option) { result |= UInt32(optionKey) }
        if contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}
