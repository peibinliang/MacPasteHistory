import AppKit
import SwiftUI

struct MainPanelView: View {
    @StateObject private var viewModel: ClipboardHistoryViewModel
    @StateObject private var actionViewModel: ContentActionPanelViewModel
    private let pasteCoordinator: PasteCoordinator
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let dismissAction: (() -> Void)?
    private let openSettingsAction: (() -> Void)?

    @State private var selectedItem: ClipboardHistoryItem?
    @State private var selectedFilter: HistoryContentFilter = .all
    @State private var selectedKeyboardItem: Int64?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showAccessibilityPermissionReminder = false
    @FocusState private var isListFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    init(
        viewModel: ClipboardHistoryViewModel,
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        actionViewModel: ContentActionPanelViewModel? = nil,
        pasteCoordinator: PasteCoordinator,
        dismissAction: (() -> Void)? = nil,
        openSettingsAction: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _actionViewModel = StateObject(wrappedValue: actionViewModel ?? ContentActionPanelViewModel())
        self.pasteCoordinator = pasteCoordinator
        self.accessibilityPermissionService = accessibilityPermissionService
        self.dismissAction = dismissAction
        self.openSettingsAction = openSettingsAction
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            sourceRibbon
            Divider().opacity(0.55)
            actionArea
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: HistoryPanelWindow.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: HistoryPanelWindow.cornerRadius,
                style: .continuous
            )
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.loadHistoryAsync()
            }
            selectedKeyboardItem = viewModel.items.first?.id
            isListFocused = true
        }
        .onChange(of: viewModel.items) {
            guard let selectedKeyboardItem,
                  viewModel.items.contains(where: { $0.id == selectedKeyboardItem }) else {
                self.selectedKeyboardItem = viewModel.items.first?.id
                return
            }
        }
        .alert(
            L10n.string("Accessibility Permission Required"),
            isPresented: $showAccessibilityPermissionReminder
        ) {
            Button(L10n.string("Open System Settings")) {
                accessibilityPermissionService.openSystemSettings()
            }
            Button(L10n.string("Later"), role: .cancel) {}
        } message: {
            Text(
                L10n.string(
                    "Allow 粘易 in System Settings → Privacy & Security → Accessibility, then try pasting again."
                )
            )
        }
        .alert(
            L10n.string("ai.consent.title"),
            isPresented: Binding(
                get: { actionViewModel.isAIRemoteProcessingConsentRequired },
                set: { if $0 == false { actionViewModel.declineAIRemoteProcessing() } }
            )
        ) {
            Button(L10n.string("ai.consent.continue")) {
                actionViewModel.acceptAIRemoteProcessing()
            }
            Button(L10n.string("Cancel"), role: .cancel) {
                actionViewModel.declineAIRemoteProcessing()
            }
        } message: {
            Text(L10n.string("ai.consent.message"))
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                    .padding(.bottom, 42)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedItem, content: historyDetailSheet)
        .onKeyPress(keys: [KeyEquivalent("k")]) { keyPress in
            if keyPress.modifiers.contains(.command), let item = selectedItemFromKeyboard {
                openAllActions(for: item)
                return .handled
            }
            return .ignored
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(AppBrand.displayName)
                .font(.headline.weight(.semibold))

            Spacer()

            Button {
                closePanel()
                if let openSettingsAction {
                    openSettingsAction()
                } else {
                    openSettings()
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(L10n.string("Settings"))
            .help(L10n.string("Settings"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        SearchBarView(
            text: $viewModel.searchText,
            tokens: viewModel.searchTokens,
            suggestions: viewModel.searchSuggestions,
            textDidChange: viewModel.updateSearchText,
            acceptSuggestion: viewModel.acceptSuggestion,
            removeToken: viewModel.removeSearchToken,
            dismissSuggestions: viewModel.dismissSearchSuggestions
        )
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var sourceRibbon: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SourceRibbonButton(
                        title: L10n.string("All"),
                        subtitle: L10n.string("Just Now"),
                        systemImage: "clock",
                        isSelected: viewModel.selectedSourceOption == nil
                    ) {
                        viewModel.selectedSourceOption = nil
                        viewModel.refreshSearch()
                    }

                    ForEach(recentSources) { source in
                        SourceRibbonButton(
                            title: source.title,
                            subtitle: relativeSourceTime(source.lastUsedAt),
                            bundleID: source.bundleID,
                            isSelected: viewModel.selectedSourceOption?.bundleID == source.bundleID
                        ) {
                            viewModel.selectedSourceOption = viewModel.sourceOptions.first {
                                $0.bundleID == source.bundleID
                            }
                            viewModel.refreshSearch()
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            filterMenu
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var filterMenu: some View {
        Menu {
            Picker(L10n.string("Type"), selection: $selectedFilter) {
                ForEach(HistoryContentFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }

            Picker(L10n.string("Time"), selection: $viewModel.selectedTimeRange) {
                ForEach(HistoryQuery.TimeRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }

            Toggle(L10n.string("Favorites"), isOn: $viewModel.isFavoritesOnly)

            Divider()

            Button(role: .destructive) {
                viewModel.clearTextHistory()
            } label: {
                Label(L10n.string("Clear Text"), systemImage: "trash")
            }
            .disabled(viewModel.items.isEmpty)
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel(L10n.string("Filters"))
        .onChange(of: selectedFilter) {
            viewModel.selectedContentType = selectedFilter.contentType
            viewModel.refreshSearch()
        }
        .onChange(of: viewModel.selectedTimeRange) { viewModel.refreshSearch() }
        .onChange(of: viewModel.isFavoritesOnly) { viewModel.refreshSearch() }
    }

    @ViewBuilder
    private var actionArea: some View {
        GeometryReader { geometry in
            let isExpanded = geometry.size.width >= 1_100
            if actionViewModel.state == .closed {
                historyContent
            } else if isExpanded {
                HStack(spacing: 0) {
                    historyContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    actionSidePanel
                        .frame(width: 400)
                }
            } else {
                actionSidePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onKeyPress(.escape) {
            handleActionEscape()
            return .handled
        }
    }

    @ViewBuilder
    private var actionSidePanel: some View {
        switch actionViewModel.state {
        case .choosing, .executing:
            ContentActionCommandPalette(viewModel: actionViewModel)
        case .previewing, .failed:
            ContentActionPreviewView(
                actionViewModel: actionViewModel,
                copyAction: { output, source in
                    if viewModel.copyActionOutput(output, sourceItem: source) { showCopyToast() }
                },
                pasteAction: { output, source in
                    pasteActionOutput(output, source: source)
                },
                saveAction: { session in
                    if let saved = viewModel.saveDerivedActionOutput(from: session) {
                        selectedKeyboardItem = saved.id
                        actionViewModel.close()
                    }
                },
                backAction: { actionViewModel.moveBack() },
                closeAction: { actionViewModel.close() }
            )
        case .closed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                L10n.string("Unable to Load History"),
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HistoryTimelineView(
                        sections: timelineSections,
                        selectedItemID: $selectedKeyboardItem,
                        highlightedTerms: viewModel.highlightedTerms,
                        detailAction: { selectedItem = $0 },
                        favoriteAction: { viewModel.toggleFavorite($0) },
                        restoreAction: { restoreAndShowFeedback($0) },
                        pasteAction: { pasteIntoPreviousApplication($0) },
                        deleteAction: { viewModel.delete($0) },
                        recommendedActions: { item in
                            actionViewModel.recommendedActions(for: item.effectiveDetectedType)
                        },
                        contentAction: { item, actionID in
                            openRecommendedActions(for: item)
                            actionViewModel.execute(actionID: actionID)
                        },
                        allActionsAction: { openAllActions(for: $0) },
                        recommendedActionsAction: { openRecommendedActions(for: $0) },
                        loadMoreAction: { viewModel.loadMoreIfNeeded(currentItem: $0) }
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .onKeyPress(.upArrow) {
                moveSelectionUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelectionDown()
                return .handled
            }
            .onKeyPress(.return) {
                if let item = selectedItemFromKeyboard {
                    pasteIntoPreviousApplication(item)
                }
                return .handled
            }
            .onKeyPress(.escape) {
                if actionViewModel.state == .closed { closePanel() }
                else { handleActionEscape() }
                return .handled
            }
            .focusable()
            .focusEffectDisabled(HistoryPanelWindow.keyboardFocusEffectDisabled)
            .focused($isListFocused)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
            Text(L10n.string("No History Yet"))
                .font(.title3.weight(.semibold))
            Text(L10n.string("Copy text or an image and it will appear here. Your history stays on this Mac."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
            Text("⇧⌘V")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var footer: some View {
        HStack {
            Text(L10n.string("Select any item to paste into the previous app"))
            Spacer()
            Text("↑↓  \(L10n.string("Navigate"))   ↩  \(L10n.string("Paste"))   esc  \(L10n.string("Close"))")
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(.thinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.45) }
    }

    private var timelineSections: [HistoryTimelineSection] {
        viewModel.timelineSections
    }

    private var recentSources: [HistoryRecentSource] {
        viewModel.recentSources
    }

    private var selectedItemFromKeyboard: ClipboardHistoryItem? {
        selectedKeyboardItem.flatMap { id in
            viewModel.items.first { $0.id == id }
        }
    }

    private var hasActiveFilters: Bool {
        selectedFilter != .all ||
            viewModel.selectedTimeRange != .all ||
            viewModel.isFavoritesOnly
    }

    private func relativeSourceTime(_ date: Date) -> String {
        SharedHistoryDisplayFormatter.shared.relativeTime(for: date)
    }

    private func historyDetailSheet(_ item: ClipboardHistoryItem) -> some View {
        HistoryDetailView(
            item: item,
            restoreAction: { restoreAndShowFeedback(item) },
            deleteAction: {
                viewModel.delete(item)
                selectedItem = nil
            },
            favoriteAction: {
                viewModel.toggleFavorite(item)
                selectedItem = viewModel.items.first(where: { $0.id == item.id })
            },
            setTypeAction: { viewModel.setUserOverrideType($0, for: item) },
            sourceRecordExists: viewModel.sourceRecordExists(for: item),
            ocrViewModel: viewModel.makeOCRViewModel()
        )
    }

    private func moveSelectionUp() {
        guard let current = selectedKeyboardItem,
              let index = viewModel.items.firstIndex(where: { $0.id == current }),
              index > 0 else { return }
        selectedKeyboardItem = viewModel.items[index - 1].id
    }

    private func moveSelectionDown() {
        guard let current = selectedKeyboardItem,
              let index = viewModel.items.firstIndex(where: { $0.id == current }),
              index < viewModel.items.count - 1 else { return }
        selectedKeyboardItem = viewModel.items[index + 1].id
    }

    private func closePanel() {
        if let dismissAction {
            dismissAction()
        } else {
            dismiss()
        }
    }

    private func showCopyToast() {
        toastMessage = L10n.string("Copied to clipboard")
        withAnimation(.easeOut(duration: 0.18)) { showToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeIn(duration: 0.18)) { showToast = false }
        }
    }

    private func restoreAndShowFeedback(_ item: ClipboardHistoryItem) {
        guard viewModel.restore(item) else { return }
        showCopyToast()
    }

    private func pasteIntoPreviousApplication(_ item: ClipboardHistoryItem) {
        guard let request = viewModel.pasteRequest(for: item) else { return }
        Task {
            let outcome = await pasteCoordinator.paste(request) {
                closePanel()
            }
            handlePasteOutcome(outcome)
        }
    }

    private func pasteActionOutput(_ output: String, source: ClipboardHistoryItem) {
        let request = viewModel.actionOutputPasteRequest(output, sourceItem: source)
        Task {
            let outcome = await pasteCoordinator.paste(request) {
                actionViewModel.close()
                closePanel()
            }
            handlePasteOutcome(outcome)
        }
    }

    private func handlePasteOutcome(_ outcome: PasteOutcome) {
        viewModel.applyPasteOutcome(outcome)
        switch PasteOutcomeFeedback.feedback(for: outcome) {
        case .none:
            break
        case .manualPaste:
            showManualPasteToast()
        case .permissionRequired:
            _ = accessibilityPermissionService.reminderIfNeeded(for: .automaticPaste)
            showAccessibilityPermissionReminder = true
            showManualPasteToast()
        }
    }

    private func showManualPasteToast() {
        toastMessage = L10n.string("Copied. Press Command-V to paste manually.")
        withAnimation(.easeOut(duration: 0.18)) { showToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeIn(duration: 0.18)) { showToast = false }
        }
    }

    private func openAllActions(for item: ClipboardHistoryItem) {
        actionViewModel.present(for: item, sourceText: item.ocrText ?? item.textContent)
    }

    private func openRecommendedActions(for item: ClipboardHistoryItem) {
        actionViewModel.present(for: item, sourceText: item.ocrText ?? item.textContent, recommendedOnly: true)
    }

    private func handleActionEscape() {
        switch ContentActionKeyboardPolicy.escapeTarget(for: actionViewModel.state) {
        case .closePalette:
            actionViewModel.close()
            isListFocused = true
        case .closePreview:
            actionViewModel.close()
            isListFocused = true
        case .closePanel:
            closePanel()
        }
    }
}

private enum HistoryContentFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.string("All")
        case .text: return L10n.string("Text")
        case .image: return L10n.string("Image")
        }
    }

    var contentType: ClipboardContentType? {
        switch self {
        case .all: return nil
        case .text: return .text
        case .image: return .image
        }
    }
}

private struct SourceRibbonButton: View {
    let title: String
    let subtitle: String
    var bundleID: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                sourceIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 50)
            .background(isSelected ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .padding(.horizontal, 10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundleID,
           let icon = PreviewImageCache.shared.applicationIcon(forBundleIdentifier: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 27, height: 27)
        } else {
            Image(systemName: systemImage ?? "app")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 27, height: 27)
        }
    }
}
