import AppKit
import SwiftUI

struct MainPanelView: View {
    @StateObject private var viewModel: ClipboardHistoryViewModel
    @StateObject private var actionViewModel: ContentActionPanelViewModel
    private let pasteCommandService: PasteCommandService
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let pasteTargetApplication: NSRunningApplication?
    private let dismissAction: (() -> Void)?

    @State private var selectedItem: ClipboardHistoryItem?
    @State private var selectedFilter: HistoryContentFilter = .all
    @State private var selectedKeyboardItem: Int64?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showAccessibilityPermissionReminder = false
    @FocusState private var isListFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    private let timelineOrganizer = HistoryTimelineOrganizer()

    init(
        viewModel: ClipboardHistoryViewModel,
        pasteCommandService: PasteCommandService = PasteCommandService(),
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        pasteTargetApplication: NSRunningApplication? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _actionViewModel = StateObject(wrappedValue: ContentActionPanelViewModel())
        self.pasteCommandService = pasteCommandService
        self.accessibilityPermissionService = accessibilityPermissionService
        self.pasteTargetApplication = pasteTargetApplication
        self.dismissAction = dismissAction
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
            viewModel.loadHistory()
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
                openSettings()
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
                    actionViewModel.close()
                    closePanel()
                    pasteTargetApplication?.activate(options: PasteActivationPolicy.options)
                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        _ = viewModel.pasteActionOutput(output, sourceItem: source, pasteCommandService: pasteCommandService)
                    }
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
                            ContentActionRegistry().recommended(for: item.effectiveDetectedType)
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
        timelineOrganizer.sections(for: viewModel.items)
    }

    private var recentSources: [HistoryRecentSource] {
        timelineOrganizer.recentSources(from: viewModel.items, limit: 6)
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
        viewModel.restore(item)
        showCopyToast()
    }

    private func pasteIntoPreviousApplication(_ item: ClipboardHistoryItem) {
        if accessibilityPermissionService.reminderIfNeeded(for: .automaticPaste) {
            showAccessibilityPermissionReminder = true
            return
        }
        guard viewModel.restore(item) else { return }
        closePanel()
        pasteTargetApplication?.activate(options: PasteActivationPolicy.options)
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            _ = pasteCommandService.sendPasteCommand()
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
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
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

private struct LegacyTimelineSectionView: View {
    let section: HistoryTimelineSection
    @Binding var selectedItemID: Int64?
    let detailAction: (ClipboardHistoryItem) -> Void
    let favoriteAction: (ClipboardHistoryItem) -> Void
    let restoreAction: (ClipboardHistoryItem) -> Void
    let pasteAction: (ClipboardHistoryItem) -> Void
    let deleteAction: (ClipboardHistoryItem) -> Void
    let loadMoreAction: (ClipboardHistoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .stroke(Color.secondary.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 9, height: 9)
                Text(section.group.title)
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    LegacyHistoryRowView(
                        item: item,
                        isSelected: selectedItemID == item.id,
                        detailAction: { detailAction(item) },
                        favoriteAction: { favoriteAction(item) },
                        restoreAction: { restoreAction(item) },
                        pasteAction: {
                            selectedItemID = item.id
                            pasteAction(item)
                        },
                        deleteAction: { deleteAction(item) }
                    )
                    .onHover { hovering in
                        if hovering { selectedItemID = item.id }
                    }
                    .onAppear { loadMoreAction(item) }

                    if index < section.items.count - 1 {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.065), lineWidth: 1)
            }
            .padding(.leading, 16)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 1)
                .padding(.top, 20)
                .padding(.bottom, -14)
                .offset(x: 4)
        }
    }
}

private struct LegacyHistoryRowView: View {
    let item: ClipboardHistoryItem
    let isSelected: Bool
    let detailAction: () -> Void
    let favoriteAction: () -> Void
    let restoreAction: () -> Void
    let pasteAction: () -> Void
    let deleteAction: () -> Void

    private let formatter = HistoryDisplayFormatter()

    var body: some View {
        HStack(spacing: 12) {
            preview

            VStack(alignment: .leading, spacing: 4) {
                Text(metadataTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(previewText)
                    .font(.body.weight(isSelected ? .medium : .regular))
                    .lineLimit(isSelected ? 2 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Text(L10n.string("Click to paste into the previous app"))
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity)
                } else if item.contentType == .image {
                    Text(sizeTitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if isSelected {
                Label(L10n.string("Paste"), systemImage: "arrow.turn.down.left")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .accessibilityHidden(true)
            }

            Button(action: favoriteAction) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(item.isFavorite ? Color.accentColor : .secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoriteTitle)
            .help(favoriteTitle)

            Menu {
                Button(action: detailAction) {
                    Label(L10n.string("Details"), systemImage: "info.circle")
                }
                Button(action: restoreAction) {
                    Label(L10n.string("Restore"), systemImage: "doc.on.clipboard")
                }
                Divider()
                Button(role: .destructive, action: deleteAction) {
                    Label(L10n.string("Delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel(L10n.string("More Actions"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isSelected ? 11 : 9)
        .background(isSelected ? Color.accentColor.opacity(0.075) : Color.clear)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.8), lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pasteAction)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(metadataTitle), \(previewText)")
        .accessibilityHint(L10n.string("Click to paste into the previous app"))
    }

    @ViewBuilder
    private var preview: some View {
        if item.contentType == .image {
            HistoryImagePreview(
                path: item.thumbnailPath,
                size: NSSize(width: 54, height: 44)
            )
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 54, height: 44)
                .background(Color.primary.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var metadataTitle: String {
        var parts = [item.contentType == .text ? L10n.string("Text") : L10n.string("Image")]
        if let sourceApp = item.sourceApp, sourceApp.isEmpty == false {
            parts.append(String(format: L10n.string("From %@"), sourceApp))
        }
        parts.append(formatter.displayTime(for: item.createdAt))
        return parts.joined(separator: " · ")
    }

    private var previewText: String {
        if item.contentType == .image {
            guard let width = item.imageWidth, let height = item.imageHeight else {
                return L10n.string("Image")
            }
            return String(format: L10n.string("Image %lldx%lld"), width, height)
        }
        guard item.textContent.isEmpty == false else { return L10n.string("Empty text") }
        return formatter.preview(for: item.textContent)
    }

    private var favoriteTitle: String {
        item.isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite")
    }

    private var sizeTitle: String {
        guard let fileSize = item.fileSize else { return L10n.string("Image") }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

private struct LegacyHistoryDetailView: View {
    let item: ClipboardHistoryItem
    let restoreAction: () -> Void
    let deleteAction: () -> Void
    let favoriteAction: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let formatter = HistoryDisplayFormatter()

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metadataCard
                    detailContent
                }
                .padding(20)
            }

            Divider()
            detailActions
        }
        .frame(width: 600, height: 520)
        .background(.regularMaterial)
    }

    private var detailHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("History Detail"))
                    .font(.headline)
                Text(formatter.displayTime(for: item.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.string("Done")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
    }

    private var metadataCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
            metadataRow(L10n.string("Type"), item.contentType == .text ? L10n.string("Text") : L10n.string("Image"))
            metadataRow(L10n.string("Size"), sizeTitle)
            if let width = item.imageWidth, let height = item.imageHeight {
                metadataRow(L10n.string("Dimensions"), "\(width)×\(height)")
            }
            if let imageFormat = item.imageFormat {
                metadataRow(L10n.string("Format"), imageFormat.rawValue.uppercased())
            }
            if let sourceApp = item.sourceApp, sourceApp.isEmpty == false {
                metadataRow(L10n.string("Source"), sourceApp)
            }
        }
        .font(.callout)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if item.contentType == .image {
            HistoryImagePreview(
                path: item.filePath,
                size: NSSize(width: 540, height: 275)
            )
            .frame(maxWidth: .infinity)
        } else {
            Text(item.textContent)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var detailActions: some View {
        HStack {
            Button(action: favoriteAction) {
                Label(favoriteTitle, systemImage: item.isFavorite ? "star.fill" : "star")
            }
            Button(role: .destructive, action: deleteAction) {
                Label(L10n.string("Delete"), systemImage: "trash")
            }
            Spacer()
            Button(action: restoreAction) {
                Label(L10n.string("Copy to Clipboard"), systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
    }

    private var favoriteTitle: String {
        item.isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite")
    }

    private var sizeTitle: String {
        if item.contentType == .image {
            guard let fileSize = item.fileSize else { return L10n.string("Image") }
            return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        }
        return String(format: L10n.string("%lld chars"), item.textLength)
    }
}
