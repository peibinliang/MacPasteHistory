import AppKit
import SwiftUI

struct HistoryDetailView: View {
    let item: ClipboardHistoryItem
    let restoreAction: () -> Void
    let deleteAction: () -> Void
    let favoriteAction: () -> Void
    let setTypeAction: (DetectedContentType?) -> Void
    let sourceRecordExists: Bool
    @ObservedObject var ocrViewModel: OCRViewModel

    @Environment(\.dismiss) private var dismiss
    private let formatter = HistoryDisplayFormatter()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 16) { metadata; content }.padding(20) }
            Divider()
            actions
        }
        .frame(width: 600, height: 520)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack { VStack(alignment: .leading, spacing: 3) { Text(L10n.string("History Detail")).font(.headline); Text(formatter.displayTime(for: item.createdAt)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(L10n.string("Done")) { dismiss() }.keyboardShortcut(.cancelAction) }
            .padding(.horizontal, 20).frame(height: 62)
    }

    private var metadata: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
            row(L10n.string("Type"), item.contentType == .text ? L10n.string("Text") : L10n.string("Image"))
            row(L10n.string("Size"), sizeTitle)
            if let width = item.imageWidth, let height = item.imageHeight { row(L10n.string("Dimensions"), "\(width)×\(height)") }
            if let imageFormat = item.imageFormat { row(L10n.string("Format"), imageFormat.rawValue.uppercased()) }
            if let sourceApp = item.sourceApp, sourceApp.isEmpty == false { row(L10n.string("Source"), sourceApp) }
            if item.isDerived, sourceRecordExists == false { row(L10n.string("Origin"), L10n.string("Source record deleted")) }
        }
        .font(.callout).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View { GridRow { Text(label).foregroundStyle(.secondary); Text(value).textSelection(.enabled) } }

    @ViewBuilder private var content: some View {
        if item.contentType == .image { HistoryImagePreview(path: item.filePath, size: NSSize(width: 540, height: 275)).frame(maxWidth: .infinity) }
        else { Text(item.textContent).font(.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color(nsColor: .textBackgroundColor).opacity(0.72)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) }
        if item.contentType == .image { OCRResultView(viewModel: ocrViewModel, item: item) }
    }

    private var actions: some View {
            HStack { Button(action: favoriteAction) { Label(favoriteTitle, systemImage: item.isFavorite ? "star.fill" : "star") }; Menu { Button(L10n.string("Automatic")) { setTypeAction(nil) }; ForEach(DetectedContentType.allCases, id: \.self) { type in Button(type.rawValue) { setTypeAction(type) } } } label: { Label(L10n.string("Type"), systemImage: "tag") }; Button(role: .destructive, action: deleteAction) { Label(L10n.string("Delete"), systemImage: "trash") }; Spacer(); Button(action: restoreAction) { Label(L10n.string("Copy to Clipboard"), systemImage: "doc.on.clipboard") }.buttonStyle(.borderedProminent) }
            .padding(.horizontal, 20).frame(height: 64)
    }

    private var favoriteTitle: String { item.isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite") }
    private var sizeTitle: String {
        if item.contentType == .image { guard let fileSize = item.fileSize else { return L10n.string("Image") }; return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file) }
        return String(format: L10n.string("%lld chars"), item.textLength)
    }
}
