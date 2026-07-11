import SwiftUI

struct MainPanelView: View {
    @StateObject private var viewModel: ClipboardHistoryViewModel
    private let pasteCommandService: PasteCommandService
    private let pasteTargetApplication: NSRunningApplication?
    @State private var selectedItem: ClipboardHistoryItem?
    @State private var selectedFilter: HistoryContentFilter = .all
    @State private var selectedKeyboardItem: Int64?
    @FocusState private var isListFocused: Bool
    @State private var showToast = false
    @State private var toastMessage = ""
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: ClipboardHistoryViewModel,
        pasteCommandService: PasteCommandService = PasteCommandService(),
        pasteTargetApplication: NSRunningApplication? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.pasteCommandService = pasteCommandService
        self.pasteTargetApplication = pasteTargetApplication
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchField
            filterBar
            historyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .onAppear {
            viewModel.loadHistory()
            isListFocused = true
            if let first = viewModel.items.first {
                selectedKeyboardItem = first.id
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .sheet(item: $selectedItem) { item in
            HistoryDetailView(
                item: item,
                restoreAction: {
                    viewModel.restore(item)
                },
                deleteAction: {
                    viewModel.delete(item)
                    selectedItem = nil
                },
                favoriteAction: {
                    viewModel.toggleFavorite(item)
                    selectedItem = viewModel.items.first { $0.id == item.id }
                }
            )
        }
    }

    private var header: some View {
        HStack {
                Text(L10n.string("Clipboard History"))
                .font(.headline)
            Spacer()
            Button {
                viewModel.clearTextHistory()
            } label: {
                Label(L10n.string("Clear Text"), systemImage: "trash")
            }
            .disabled(viewModel.items.isEmpty)
        }
    }

    private var searchField: some View {
        TextField(L10n.string("Search text history"), text: $viewModel.searchText)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                viewModel.search()
            }
            .onChange(of: viewModel.searchText) {
                viewModel.search()
            }
    }

    // MARK: - Keyboard navigation

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
        dismiss()
    }

    private func showCopyToast() {
        toastMessage = L10n.string("Copied to clipboard")
        withAnimation { showToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { showToast = false }
        }
    }

    private func restoreAndShowFeedback(_ item: ClipboardHistoryItem) {
        viewModel.restore(item)
        showCopyToast()
    }

    private func pasteIntoPreviousApplication(_ item: ClipboardHistoryItem) {
        guard viewModel.restore(item) else {
            return
        }
        closePanel()
        pasteTargetApplication?.activate(options: [])
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            pasteCommandService.sendPasteCommand()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $viewModel.isFavoritesOnly) {
                Label(L10n.string("Favorites"), systemImage: "star.fill")
            }
            .toggleStyle(.checkbox)
            .onChange(of: viewModel.isFavoritesOnly) {
                viewModel.loadHistory()
            }

            Picker(L10n.string("Type"), selection: $selectedFilter) {
                ForEach(HistoryContentFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .onChange(of: selectedFilter) {
                viewModel.selectedContentType = selectedFilter.contentType
                viewModel.loadHistory()
            }

            Picker(L10n.string("Time"), selection: $viewModel.selectedTimeRange) {
                ForEach(HistoryQuery.TimeRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .frame(width: 140)
            .onChange(of: viewModel.selectedTimeRange) {
                viewModel.loadHistory()
            }

            Picker(L10n.string("Source"), selection: sourceSelectionBinding) {
                Text(L10n.string("All Sources")).tag("")
                ForEach(viewModel.sourceOptions) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .frame(width: 180)
            .onChange(of: viewModel.selectedSourceOption) {
                viewModel.loadHistory()
            }
        }
    }

    private var sourceSelectionBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedSourceOption?.id ?? "" },
            set: { id in
                viewModel.selectedSourceOption = viewModel.sourceOptions.first { $0.id == id }
                viewModel.loadHistory()
            }
        )
    }

    @ViewBuilder
    private var historyContent: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        } else if viewModel.items.isEmpty {
            ContentUnavailableView(L10n.string("No History"), systemImage: "doc.on.clipboard")
        } else {
            List(selection: $selectedKeyboardItem) {
                ForEach(viewModel.items) { item in
                    HistoryRowView(
                        item: item,
                        detailAction: {
                            selectedItem = item
                        },
                        favoriteAction: {
                            viewModel.toggleFavorite(item)
                        },
                        restoreAction: {
                            restoreAndShowFeedback(item)
                        },
                        pasteAction: {
                            pasteIntoPreviousApplication(item)
                        },
                        deleteAction: {
                            viewModel.delete(item)
                        }
                    )
                    .tag(item.id)
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentItem: item)
                    }
                }
            }
            .listStyle(.inset)
            .onKeyPress(.upArrow) {
                moveSelectionUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelectionDown()
                return .handled
            }
            .onKeyPress(.return) {
                if let item = selectedKeyboardItem.flatMap({ id in viewModel.items.first(where: { $0.id == id }) }) {
                    restoreAndShowFeedback(item)
                }
                return .handled
            }
            .onKeyPress(.escape) {
                closePanel()
                return .handled
            }
            .focusable()
            .focused($isListFocused)
        }
    }
}

private enum HistoryContentFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return L10n.string("All")
        case .text:
            return L10n.string("Text")
        case .image:
            return L10n.string("Image")
        }
    }

    var contentType: ClipboardContentType? {
        switch self {
        case .all:
            return nil
        case .text:
            return .text
        case .image:
            return .image
        }
    }
}

private struct HistoryRowView: View {
    let item: ClipboardHistoryItem
    let detailAction: () -> Void
    let favoriteAction: () -> Void
    let restoreAction: () -> Void
    let pasteAction: () -> Void
    let deleteAction: () -> Void

    private let formatter = HistoryDisplayFormatter()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                if item.contentType == .image {
                    HistoryImagePreview(path: item.thumbnailPath, size: NSSize(width: 64, height: 48))
                }

                VStack(alignment: .leading, spacing: 6) {
                    metadataLine
                    Text(previewText)
                        .font(.body)
                        .lineLimit(3, reservesSpace: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                ExclusiveGesture(
                    TapGesture(count: 2),
                    TapGesture(count: 1)
                )
                .onEnded { value in
                    switch value {
                    case .first:
                        pasteAction()
                    case .second:
                        detailAction()
                    }
                }
            )

            HStack(spacing: 6) {
                Button(action: favoriteAction) {
                    Label(favoriteTitle, systemImage: item.isFavorite ? "star.fill" : "star")
                }
                .labelStyle(.iconOnly)
                .help(favoriteTitle)

                Button(action: restoreAction) {
                    Label(L10n.string("Restore"), systemImage: "arrow.uturn.backward")
                }
                .labelStyle(.iconOnly)
                .help(L10n.string("Restore"))

                Button(role: .destructive, action: deleteAction) {
                    Label(L10n.string("Delete"), systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .help(L10n.string("Delete"))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }

    private var metadataLine: some View {
        HStack(spacing: 8) {
            Label(contentTypeTitle, systemImage: item.contentType == .text ? "doc.text" : "photo")
            Text(formatter.displayTime(for: item.createdAt))
            Text(sizeTitle)
            if let sourceApp = item.sourceApp, sourceApp.isEmpty == false {
                Text(sourceApp)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var previewText: String {
        if item.contentType == .image {
            guard let width = item.imageWidth, let height = item.imageHeight else {
                return L10n.string("Image")
            }
            return String(format: L10n.string("Image %lldx%lld"), width, height)
        }

        guard item.textContent.isEmpty == false else {
            return L10n.string("Empty text")
        }

        return formatter.preview(for: item.textContent)
    }

    private var contentTypeTitle: String {
        item.contentType == .text ? L10n.string("Text") : L10n.string("Image")
    }

    private var favoriteTitle: String {
        item.isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite")
    }

    private var sizeTitle: String {
        if item.contentType == .image {
            guard let fileSize = item.fileSize else {
                return L10n.string("Image")
            }
            return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        }

        return String(format: L10n.string("%lld chars"), item.textLength)
    }
}

private struct HistoryDetailView: View {
    let item: ClipboardHistoryItem
    let restoreAction: () -> Void
    let deleteAction: () -> Void
    let favoriteAction: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let formatter = HistoryDisplayFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("History Detail"))
                        .font(.headline)
                    Text(formatter.displayTime(for: item.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.string("Done")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            metadataGrid

            detailContent

            HStack {
                Button(action: favoriteAction) {
                    Label(item.isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite"), systemImage: item.isFavorite ? "star.fill" : "star")
                }
                Spacer()
                Button(action: restoreAction) {
                    Label(L10n.string("Restore"), systemImage: "arrow.uturn.backward")
                }
                Button(role: .destructive, action: deleteAction) {
                    Label(L10n.string("Delete"), systemImage: "trash")
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            metadataRow(L10n.string("Type"), item.contentType == .text ? L10n.string("Text") : L10n.string("Image"))
            metadataRow(L10n.string("Created"), formatter.displayTime(for: item.createdAt))
            metadataRow(L10n.string("Size"), sizeTitle)
            if let width = item.imageWidth, let height = item.imageHeight {
                metadataRow(L10n.string("Dimensions"), "\(width)x\(height)")
            }
            if let imageFormat = item.imageFormat {
                metadataRow(L10n.string("Format"), imageFormat.rawValue.uppercased())
            }
            if let sourceApp = item.sourceApp, sourceApp.isEmpty == false {
                metadataRow(L10n.string("Source"), sourceApp)
            }
            if let sourceBundleID = item.sourceBundleID, sourceBundleID.isEmpty == false {
                metadataRow(L10n.string("Bundle ID"), sourceBundleID)
            }
        }
        .font(.caption)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if item.contentType == .image {
            ScrollView {
                HistoryImagePreview(path: item.filePath, size: NSSize(width: 440, height: 280))
                    .padding(12)
                    .frame(maxWidth: .infinity)
            }
            .frame(minHeight: 260)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ScrollView {
                Text(item.textContent)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 220)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sizeTitle: String {
        if item.contentType == .image {
            guard let fileSize = item.fileSize else {
                return L10n.string("Image")
            }
            return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        }

        return String(format: L10n.string("%lld chars"), item.textLength)
    }
}

private struct HistoryImagePreview: View {
    let path: String?
    let size: NSSize

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var image: NSImage? {
        guard let path else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }
}
