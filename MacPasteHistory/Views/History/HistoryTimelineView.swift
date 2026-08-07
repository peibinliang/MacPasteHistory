import SwiftUI

struct HistoryTimelineView: View {
    let sections: [HistoryTimelineSection]
    @Binding var selectedItemID: Int64?
    let highlightedTerms: [String]
    let detailAction: (ClipboardHistoryItem) -> Void
    let favoriteAction: (ClipboardHistoryItem) -> Void
    let restoreAction: (ClipboardHistoryItem) -> Void
    let pasteAction: (ClipboardHistoryItem) -> Void
    let deleteAction: (ClipboardHistoryItem) -> Void
    let recommendedActions: (ClipboardHistoryItem) -> [any ContentAction]
    let contentAction: (ClipboardHistoryItem, ContentActionID) -> Void
    let allActionsAction: (ClipboardHistoryItem) -> Void
    let recommendedActionsAction: (ClipboardHistoryItem) -> Void
    let loadMoreAction: (ClipboardHistoryItem) -> Void

    var body: some View {
        ForEach(sections) { section in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { Circle().stroke(Color.secondary.opacity(0.55), lineWidth: 1.5).frame(width: 9, height: 9); Text(section.group.title).font(.callout.weight(.semibold)) }
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        HistoryRowView(item: item, isSelected: selectedItemID == item.id, highlightedTerms: highlightedTerms, detailAction: { detailAction(item) }, favoriteAction: { favoriteAction(item) }, restoreAction: { restoreAction(item) }, pasteAction: { selectedItemID = item.id; pasteAction(item) }, deleteAction: { deleteAction(item) }, recommendedActions: recommendedActions(item), contentAction: { contentAction(item, $0) }, allActionsAction: { allActionsAction(item) }, recommendedActionsAction: { recommendedActionsAction(item) })
                            .onHover { if $0 { selectedItemID = item.id } }.onAppear { loadMoreAction(item) }
                        if index < section.items.count - 1 { Divider().padding(.leading, 78) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.62)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.065), lineWidth: 1) }.padding(.leading, 16)
            }
            .overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.16)).frame(width: 1).padding(.top, 20).padding(.bottom, -14).offset(x: 4) }
        }
    }
}
