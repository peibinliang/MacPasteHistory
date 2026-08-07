import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    let tokens: [SearchToken]
    let suggestions: [SearchSuggestion]
    let textDidChange: (String) -> Void
    let acceptSuggestion: (SearchSuggestion) -> Void
    let removeToken: (SearchToken) -> Void
    let dismissSuggestions: () -> Void
    @State private var selectedSuggestionIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(L10n.string("Search clipboard content"), text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: text) { _, newText in
                    selectedSuggestionIndex = 0
                    textDidChange(newText)
                }
                .onKeyPress(.downArrow) { moveSuggestion(by: 1) }
                .onKeyPress(.upArrow) { moveSuggestion(by: -1) }
                .onKeyPress(.return) { acceptSelectedSuggestion() }
                .onKeyPress(.escape) { dismissSuggestionMenu() }
            if tokens.isEmpty == false {
                FlowLayout(spacing: 5) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        SearchTokenView(token: token, title: String(text[token.range]), removeAction: { removeToken(token) })
                    }
                }
            }
            if suggestions.isEmpty == false {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SearchSuggestionView(
                            suggestion: suggestion,
                            isSelected: index == selectedSuggestionIndex,
                            action: { accept(suggestion) }
                        )
                    }
                }
                    .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func moveSuggestion(by amount: Int) -> KeyPress.Result {
        guard suggestions.isEmpty == false else { return .ignored }
        selectedSuggestionIndex = (selectedSuggestionIndex + amount + suggestions.count) % suggestions.count
        return .handled
    }

    private func acceptSelectedSuggestion() -> KeyPress.Result {
        guard suggestions.indices.contains(selectedSuggestionIndex) else { return .ignored }
        accept(suggestions[selectedSuggestionIndex])
        return .handled
    }

    private func dismissSuggestionMenu() -> KeyPress.Result {
        guard suggestions.isEmpty == false else { return .ignored }
        dismissSuggestions()
        return .handled
    }

    private func accept(_ suggestion: SearchSuggestion) {
        acceptSuggestion(suggestion)
        selectedSuggestionIndex = 0
        isFocused = true
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { CGSize(width: proposal.width ?? 0, height: subviews.isEmpty ? 0 : 28) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { var x = bounds.minX; for view in subviews { let size = view.sizeThatFits(.unspecified); view.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(size)); x += size.width + spacing } }
}
