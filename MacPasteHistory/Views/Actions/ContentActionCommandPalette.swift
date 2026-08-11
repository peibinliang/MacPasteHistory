import SwiftUI

struct ContentActionCommandPalette: View {
    @ObservedObject var viewModel: ContentActionPanelViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardSelection: ContentActionID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.showsRecommendedActions ? L10n.string("Recommended Actions") : L10n.string("All Actions"))
                    .font(.headline)
                Spacer()
                Text("⌘K").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            if case .executing = viewModel.state {
                ProgressView(L10n.string("ai.polishing.progress"))
                    .controlSize(.small)
            }
            TextField(L10n.string("Search actions"), text: $viewModel.commandSearchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.availableActions, id: \.id) { action in
                        Button {
                            keyboardSelection = action.id
                            viewModel.execute(actionID: action.id)
                        } label: {
                            HStack {
                                Text(L10n.string(action.titleKey))
                                Spacer()
                                if keyboardSelection == action.id { Image(systemName: "return") }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(keyboardSelection == action.id ? Color.accentColor.opacity(0.14) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ContentActionAccessibilityPresentation.actionLabel(action))
                        .accessibilityHint(L10n.string(ContentActionAccessibilityPresentation.actionHint))
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            isSearchFocused = true
            keyboardSelection = viewModel.availableActions.first?.id
        }
        .onChange(of: viewModel.commandSearchText) {
            keyboardSelection = viewModel.availableActions.first?.id
        }
        .onKeyPress(.upArrow) { move(.up); return .handled }
        .onKeyPress(.downArrow) { move(.down); return .handled }
        .onKeyPress(.return) {
            if let keyboardSelection { viewModel.execute(actionID: keyboardSelection) }
            return .handled
        }
    }

    private func move(_ direction: ContentActionKeyboardDirection) {
        keyboardSelection = ContentActionKeyboardPolicy.moveSelection(
            current: keyboardSelection,
            actions: viewModel.availableActions.map(\.id),
            direction: direction
        )
    }
}
