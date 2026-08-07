import SwiftUI

struct SearchSuggestionView: View {
    let suggestion: SearchSuggestion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { Text(suggestion.title).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 6) }
            .buttonStyle(.plain)
            .background(isSelected ? Color.accentColor.opacity(0.14) : .clear)
    }
}
