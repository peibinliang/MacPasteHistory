import Foundation

struct HistoryQuery {
    let keyword: String?
    let favoritesOnly: Bool
    let contentType: ClipboardContentType?
    let limit: Int
    let offset: Int

    init(
        keyword: String? = nil,
        favoritesOnly: Bool = false,
        contentType: ClipboardContentType? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.keyword = keyword
        self.favoritesOnly = favoritesOnly
        self.contentType = contentType
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}
