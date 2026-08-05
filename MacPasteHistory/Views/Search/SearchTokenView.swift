import SwiftUI

struct SearchTokenView: View {
    let token: SearchToken
    let title: String
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title).font(.caption)
            Button(action: removeAction) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Remove search token"))
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12))
        .clipShape(Capsule())
    }
}
