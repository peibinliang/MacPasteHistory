import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var updateService: UpdateService
    @State private var showClearConfirmation = false
    @State private var showRemoveAIKeyConfirmation = false
    @State private var selectedCategory: SettingsCategory? = .general
    private let appVersion: any AppVersionProviding

    init(
        viewModel: SettingsViewModel,
        updateService: UpdateService,
        appVersion: any AppVersionProviding = AppVersionInfo.current
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.updateService = updateService
        self.appVersion = appVersion
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.title, systemImage: category.systemImage)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            settingsPage(selectedCategory ?? .general)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, minHeight: 560)
        .onAppear { viewModel.loadSettings() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshAutomaticPastePermissionState()
        }
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
        .alert(
            L10n.string("Disable Sensitive Content Filtering?"),
            isPresented: $viewModel.showSensitiveContentWarning
        ) {
            Button(L10n.string("Keep Filtering"), role: .cancel) {
                viewModel.cancelSensitiveContentFilteringDisabled()
            }
            Button(L10n.string("Disable Filtering"), role: .destructive) {
                viewModel.confirmSensitiveContentFilteringDisabled()
            }
        } message: {
            Text(L10n.string("Detected passwords, tokens, identity numbers, and payment card numbers may be stored in the local unencrypted history database."))
        }
        .alert(L10n.string("ai.settings.remove-key-title"), isPresented: $showRemoveAIKeyConfirmation) {
            Button(L10n.string("Cancel"), role: .cancel) {}
            Button(L10n.string("Remove"), role: .destructive) { viewModel.removeAIAPIKey() }
        } message: {
            Text(L10n.string("ai.settings.remove-key-message"))
        }
    }

    @ViewBuilder
    private func settingsPage(_ category: SettingsCategory) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title)
                        .font(.title2.weight(.semibold))
                    Text(category.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            Form {
                switch category {
                case .general:
                    recordingSection
                    shortcutSection
                    appearanceSection
                    languageSection
                case .privacy:
                    privacySection
                case .ai:
                    aiConfigurationSection
                    aiUsageSection
                case .storage:
                    retentionSection
                    limitsSection
                    storageSection
                    dataSection
                case .about:
                    aboutSection
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            Toggle(L10n.string("Automatic Paste"), isOn: $viewModel.automaticPasteEnabled)
                .onChange(of: viewModel.automaticPasteEnabled) { _, newValue in
                    viewModel.updateAutomaticPasteEnabled(newValue)
                }
            Text(L10n.string("When disabled, selected content is copied and you can paste it manually."))
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.isAutomaticPastePermissionRequired {
                HStack {
                    Text(L10n.string("Accessibility permission is required for Automatic Paste."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button(L10n.string("Open System Settings")) {
                        viewModel.openAccessibilitySettings()
                    }
                }
            }
        }
    }

    private var privacySection: some View {
        Section(L10n.string("Privacy Controls")) {
            Toggle(L10n.string("Pause recording"), isOn: $viewModel.recordingPaused)
                .onChange(of: viewModel.recordingPaused) { _, newValue in
                    viewModel.updateRecordingPaused(newValue)
                }

            Toggle(L10n.string("Filter sensitive content"), isOn: $viewModel.filterSensitiveContent)
                .onChange(of: viewModel.filterSensitiveContent) { _, enabled in
                    viewModel.requestSensitiveContentFiltering(enabled)
                }
            Text(L10n.string("When enabled, detected passwords, tokens, identity numbers, and payment card numbers are not saved."))
                .font(.caption)
                .foregroundStyle(.secondary)

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

    private var aiConfigurationSection: some View {
        Section(L10n.string("ai.settings.configuration")) {
            Text(L10n.string("ai.settings.remote-processing-note"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField(L10n.string("ai.settings.model"), text: $viewModel.aiModelIdentifier)
                    .onSubmit { viewModel.updateAIModelIdentifier(viewModel.aiModelIdentifier) }
                Button(L10n.string("Reset")) { viewModel.resetAIModelIdentifier() }
            }
            Picker(L10n.string("ai.settings.translation-target"), selection: $viewModel.aiTranslationTarget) {
                ForEach(AITranslationTarget.allCases) { target in
                    Text(L10n.string(target.titleKey)).tag(target)
                }
            }
            .onChange(of: viewModel.aiTranslationTarget) { _, target in
                viewModel.updateAITranslationTarget(target)
            }
            SecureField(L10n.string("ai.settings.api-key-placeholder"), text: $viewModel.aiAPIKeyEntry)
            HStack {
                Button(L10n.string(viewModel.hasStoredAIAPIKey ? "ai.settings.replace-key" : "ai.settings.save-key")) {
                    viewModel.saveAIAPIKey()
                }
                .disabled(viewModel.aiAPIKeyEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if viewModel.hasStoredAIAPIKey {
                    Label(L10n.string("ai.settings.key-stored"), systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Button(L10n.string("Remove"), role: .destructive) {
                        showRemoveAIKeyConfirmation = true
                    }
                }
            }
            if let message = viewModel.aiCredentialMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var aiUsageSection: some View {
        Section(L10n.string("ai.settings.token-usage")) {
            Text(L10n.string("ai.settings.provider-reported"))
                .font(.caption)
                .foregroundStyle(.secondary)
            usageSummary(title: L10n.string("ai.settings.current-model"), summary: viewModel.selectedModelAIUsage)
            usageSummary(title: L10n.string("ai.settings.all-models"), summary: viewModel.allModelsAIUsage)
        }
    }

    private func usageSummary(title: String, summary: AITokenUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.semibold))
            Text(String(
                format: L10n.string("ai.settings.token-summary"),
                Int64(summary.inputTokens), Int64(summary.outputTokens), Int64(summary.totalTokens)
            ))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
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

    private var appearanceSection: some View {
        Section(L10n.string("Appearance")) {
            Picker(L10n.string("Appearance"), selection: $viewModel.selectedAppearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(L10n.string(appearance.titleKey)).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedAppearance) { _, newValue in
                viewModel.updateAppearance(newValue)
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

    private var aboutSection: some View {
        Section(L10n.string("About & Updates")) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appVersion.displayName)
                        .font(.headline)
                    Text(appVersion.localizedVersionText)
                        .foregroundStyle(.secondary)
                }
            }

            if let repositoryURL = URL(string: "https://github.com/peibinliang/MacPasteHistory") {
                Link(L10n.string("View on GitHub"), destination: repositoryURL)
            }

            Toggle(
                L10n.string("Automatically check for updates"),
                isOn: Binding(
                    get: { updateService.automaticallyChecksForUpdates },
                    set: { updateService.setAutomaticallyChecksForUpdates($0) }
                )
            )

            Button(L10n.string("Check for Updates…")) {
                updateService.checkForUpdates()
            }
            .disabled(!updateService.canStartManualUpdateCheck)

            if let statusMessage = updateService.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(updateService.errorMessage == nil ? Color.secondary : Color.red)
            }
        }
    }

    private func restartApp() {
        AppRelauncher().relaunchAfterTermination(bundlePath: Bundle.main.bundlePath)
        NSApp.terminate(nil)
    }
}

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case privacy
    case ai
    case storage
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.string("General")
        case .privacy: return L10n.string("Privacy")
        case .ai: return L10n.string("ai.settings.title")
        case .storage: return L10n.string("Storage and Data")
        case .about: return L10n.string("About & Updates")
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return L10n.string("Recording, startup, shortcuts, and language")
        case .privacy:
            return L10n.string("Control where clipboard history is recorded")
        case .ai:
            return L10n.string("ai.settings.subtitle")
        case .storage:
            return L10n.string("Retention, limits, and local data")
        case .about:
            return L10n.string("Version information and software updates")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .privacy: return "hand.raised"
        case .ai: return "sparkles"
        case .storage: return "internaldrive"
        case .about: return "info.circle"
        }
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
