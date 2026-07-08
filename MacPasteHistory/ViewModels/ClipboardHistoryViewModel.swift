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
            errorMessage = NSLocalizedString("Failed to load clipboard history.", comment: "Error: load failed")
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
            errorMessage = NSLocalizedString("Failed to load more clipboard history.", comment: "Error: load more failed")
        }
    }

    @discardableResult
    func restore(_ item: ClipboardHistoryItem) -> Bool {
        if item.contentType == .image {
            return restoreImage(item)
        }

        guard writer.writeText(item.textContent) else {
            errorMessage = NSLocalizedString("Failed to restore text to clipboard.", comment: "Error: restore text failed")
            return false
        }
        errorMessage = nil
        return true
    }

    func delete(_ item: ClipboardHistoryItem) {
        do {
            if item.contentType == .image {
                imageStorageService?.deleteImageFiles(for: item)
            }
            try repository.deleteItem(id: item.id)
            loadHistory()
        } catch {
            errorMessage = NSLocalizedString("Failed to delete clipboard history item.", comment: "Error: delete failed")
        }
    }

    func toggleFavorite(_ item: ClipboardHistoryItem) {
        do {
            try repository.setFavorite(!item.isFavorite, id: item.id)
            loadHistory()
        } catch {
            errorMessage = NSLocalizedString("Failed to update favorite state.", comment: "Error: favorite update failed")
        }
    }

    func clearTextHistory() {
        do {
            try repository.clearTextHistory()
            loadHistory()
        } catch {
            errorMessage = NSLocalizedString("Failed to clear clipboard history.", comment: "Error: clear failed")
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

    private func restoreImage(_ item: ClipboardHistoryItem) -> Bool {
        guard let filePath = item.filePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              writer.writeImage(data) else {
            errorMessage = NSLocalizedString("Failed to restore image to clipboard.", comment: "Error: restore image failed")
            return false
        }
        errorMessage = nil
        return true
    }
}
