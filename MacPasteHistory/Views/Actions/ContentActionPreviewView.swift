import SwiftUI

struct ContentActionPreviewView: View {
    @ObservedObject var actionViewModel: ContentActionPanelViewModel
    let copyAction: (String, ClipboardHistoryItem) -> Void
    let pasteAction: (String, ClipboardHistoryItem) -> Void
    let saveAction: (ActionSession) -> Void
    let backAction: () -> Void
    let closeAction: () -> Void
    @State private var showsOriginal = false

    var body: some View {
        guard let session = actionViewModel.session else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                header(session: session)
                Divider()
                Picker("", selection: $showsOriginal) {
                    Text(L10n.string("Result")).tag(false)
                    Text(L10n.string("Original")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(16)
                if let failureMessageKey = actionViewModel.failureMessageKey {
                    ContentUnavailableView(
                        L10n.string("Action Failed"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(L10n.string(failureMessageKey))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showsOriginal {
                    ScrollView { Text(session.sourceText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(16) }
                } else {
                    SyntaxHighlightedTextView(text: Binding(
                        get: { actionViewModel.editedOutput },
                        set: { actionViewModel.updateEditedOutput($0) }
                    ), syntax: session.steps.last?.originalResult.syntax ?? .plainText)
                    .accessibilityValue(L10n.string(ContentActionAccessibilityPresentation.resultEditedValue))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                if actionViewModel.hasUsableResult {
                    stepSummary(session)
                    Divider()
                    HStack {
                        Button(L10n.string("Restore Result")) { actionViewModel.restoreCurrentOutput() }
                        Button(L10n.string("Copy Result")) { copyAction(actionViewModel.editedOutput, session.sourceItem) }
                            .keyboardShortcut("c", modifiers: .command)
                        Button(L10n.string("Paste Result")) { pasteAction(actionViewModel.editedOutput, session.sourceItem) }
                            .keyboardShortcut(.return, modifiers: .command)
                        Spacer()
                        Button(L10n.string("Save as New Record")) { saveAction(session) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                }
            }
        )
    }

    private func header(session: ActionSession) -> some View {
        HStack(spacing: 10) {
            Button(action: backAction) { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .help(L10n.string("Back"))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.steps.last.map { L10n.string($0.actionTitleKey) } ?? L10n.string("Actions"))
                    .font(.headline)
                Text(session.sourceItem.effectiveDetectedType.localizedTitle()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: closeAction) { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .help(L10n.string("Close"))
        }
        .padding(16)
    }

    private func stepSummary(_ session: ActionSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.string("Steps")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(session.localizedActionSummary()).font(.caption).lineLimit(2)
            ForEach(actionViewModel.notices, id: \.messageKey) { notice in
                Label(L10n.string(notice.messageKey), systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.string(notice.messageKey))
            }
            if actionViewModel.copyVariants.isEmpty == false {
                HStack {
                    ForEach(actionViewModel.copyVariants) { variant in
                        Button(L10n.string(variant.titleKey)) {
                            copyAction(variant.value, session.sourceItem)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
