import AppKit
import SwiftUI

struct HistoryRowPresentation {
    let item: ClipboardHistoryItem
    let isSelected: Bool
    private let formatter = HistoryDisplayFormatter()

    var metadataTitle: String {
        var parts = [item.contentType == .text ? L10n.string("Text") : L10n.string("Image")]
        if let sourceApp = item.sourceApp, sourceApp.isEmpty == false {
            parts.append(String(format: L10n.string("From %@"), sourceApp))
        }
        parts.append(formatter.displayTime(for: item.createdAt))
        return parts.joined(separator: " · ")
    }

    var previewText: String {
        if item.contentType == .image {
            guard let width = item.imageWidth, let height = item.imageHeight else { return L10n.string("Image") }
            return String(format: L10n.string("Image %lldx%lld"), width, height)
        }
        guard item.textContent.isEmpty == false else { return L10n.string("Empty text") }
        return formatter.preview(for: item.textContent)
    }

    var favoriteTitle: String { item.isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite") }
    var selectedRowHint: String? { isSelected ? L10n.string("Click to paste into the previous app") : nil }
    var sizeTitle: String {
        guard let fileSize = item.fileSize else { return L10n.string("Image") }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

struct HistoryRowView: View {
    let item: ClipboardHistoryItem
    let isSelected: Bool
    let highlightedTerms: [String]
    let detailAction: () -> Void
    let favoriteAction: () -> Void
    let restoreAction: () -> Void
    let pasteAction: () -> Void
    let deleteAction: () -> Void

    private var presentation: HistoryRowPresentation { HistoryRowPresentation(item: item, isSelected: isSelected) }

    var body: some View {
        HStack(spacing: 12) {
            preview
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.metadataTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                KeywordHighlightedText(text: presentation.previewText, terms: highlightedTerms)
                    .font(.body.weight(isSelected ? .medium : .regular))
                    .lineLimit(isSelected ? 2 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let selectedRowHint = presentation.selectedRowHint {
                    Text(selectedRowHint).font(.caption).foregroundStyle(Color.accentColor).transition(.opacity)
                } else if item.contentType == .image {
                    Text(presentation.sizeTitle).font(.caption).foregroundStyle(.tertiary)
                }
            }
            if isSelected {
                Label(L10n.string("Paste"), systemImage: "arrow.turn.down.left").font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor).labelStyle(.titleAndIcon).padding(.horizontal, 10).accessibilityHidden(true)
            }
            Button(action: favoriteAction) { Image(systemName: item.isFavorite ? "star.fill" : "star").foregroundStyle(item.isFavorite ? Color.accentColor : .secondary).frame(width: 26, height: 26) }
                .buttonStyle(.plain).accessibilityLabel(presentation.favoriteTitle).help(presentation.favoriteTitle)
            Menu {
                Button(action: detailAction) { Label(L10n.string("Details"), systemImage: "info.circle") }
                Button(action: restoreAction) { Label(L10n.string("Restore"), systemImage: "doc.on.clipboard") }
                Divider()
                Button(role: .destructive, action: deleteAction) { Label(L10n.string("Delete"), systemImage: "trash") }
            } label: { Image(systemName: "ellipsis").frame(width: 26, height: 26) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).accessibilityLabel(L10n.string("More Actions"))
        }
        .padding(.horizontal, 12).padding(.vertical, isSelected ? 11 : 9)
        .background(isSelected ? Color.accentColor.opacity(0.075) : Color.clear)
        .overlay { if isSelected { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.accentColor.opacity(0.8), lineWidth: 1.5) } }
        .contentShape(Rectangle()).onTapGesture(perform: pasteAction).animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityElement(children: .contain).accessibilityLabel("\(presentation.metadataTitle), \(presentation.previewText)").accessibilityHint(L10n.string("Click to paste into the previous app"))
    }

    @ViewBuilder private var preview: some View {
        if item.contentType == .image { HistoryImagePreview(path: item.thumbnailPath, size: NSSize(width: 54, height: 44)) }
        else {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "doc.text").font(.system(size: 22, weight: .light)).foregroundStyle(.secondary)
                if let typeIcon = typeIcon {
                    Image(systemName: typeIcon).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                        .accessibilityLabel(item.effectiveDetectedType.rawValue)
                        .help(item.effectiveDetectedType.rawValue)
                }
            }
            .frame(width: 54, height: 44).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var typeIcon: String? {
        switch item.effectiveDetectedType {
        case .json: "curlybraces"
        case .jwt: "checkmark.seal"
        case .url: "link"
        case .base64: "textformat.abc"
        case .timestamp: "clock"
        case .sql: "cylinder"
        case .shell: "terminal"
        case .plainText, .image: nil
        }
    }
}
