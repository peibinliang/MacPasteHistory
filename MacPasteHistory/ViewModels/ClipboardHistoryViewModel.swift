import Foundation
import Combine

@MainActor
final class ClipboardHistoryViewModel: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published var searchText = ""
    @Published var isFavoritesOnly = false
    @Published var selectedContentType: ClipboardContentType?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingMore = false

    private let repository: ClipboardHistoryRepository
    private let writer: ClipboardWriter
    private let imageStorageService: ImageStorageService?
    private let pageSize: Int
    private var currentOffset = 0
    private var canLoadMore = true
    private var historyDidChangeCancellable: AnyCancellable?

    init(
        repository: ClipboardHistoryRepository,
        writer: ClipboardWriter,
        imageStorageService: ImageStorageService? = nil,
        pageSize: Int = 50
    ) {
        self.repository = repository
        self.writer = writer
        self.imageStorageService = imageStorageService
        self.pageSize = pageSize
        historyDidChangeCancellable = NotificationCenter.default.publisher(for: .clipboardHistoryDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadHistory()
            }
    }

    func loadHistory() {
        do {
            currentOffset = 0
            let loadedItems = try repository.fetchHistory(query: currentQuery(offset: currentOffset))
            items = loadedItems
            currentOffset = loadedItems.count
            canLoadMore = loadedItems.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load clipboard history."
        }
    }

    func search() {
        loadHistory()
    }

    func loadMoreIfNeeded(currentItem: ClipboardHistoryItem?) {
        guard canLoadMore, isLoadingMore == false else {
            return
        }
        guard currentItem?.id == items.last?.id else {
            return
        }

        isLoadingMore = true
        defer {
            isLoadingMore = false
        }

        do {
            let loadedItems = try repository.fetchHistory(query: currentQuery(offset: currentOffset))
            items.append(contentsOf: loadedItems)
            currentOffset += loadedItems.count
            canLoadMore = loadedItems.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load more clipboard history."
        }
    }

    func restore(_ item: ClipboardHistoryItem) {
        if item.contentType == .image {
            restoreImage(item)
            return
        }

        guard writer.writeText(item.textContent) else {
            errorMessage = "Failed to restore text to clipboard."
            return
        }
        errorMessage = nil
    }

    func delete(_ item: ClipboardHistoryItem) {
        do {
            if item.contentType == .image {
                imageStorageService?.deleteImageFiles(for: item)
            }
            try repository.deleteItem(id: item.id)
            loadHistory()
        } catch {
            errorMessage = "Failed to delete clipboard history item."
        }
    }

    func toggleFavorite(_ item: ClipboardHistoryItem) {
        do {
            try repository.setFavorite(!item.isFavorite, id: item.id)
            loadHistory()
        } catch {
            errorMessage = "Failed to update favorite state."
        }
    }

    func clearTextHistory() {
        do {
            try repository.clearTextHistory()
            loadHistory()
        } catch {
            errorMessage = "Failed to clear clipboard history."
        }
    }

    private func currentQuery(offset: Int) -> HistoryQuery {
        HistoryQuery(
            keyword: searchText,
            favoritesOnly: isFavoritesOnly,
            contentType: selectedContentType,
            limit: pageSize,
            offset: offset
        )
    }

    private func restoreImage(_ item: ClipboardHistoryItem) {
        guard let filePath = item.filePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              writer.writeImage(data) else {
            errorMessage = "Failed to restore image to clipboard."
            return
        }
        errorMessage = nil
    }
}
