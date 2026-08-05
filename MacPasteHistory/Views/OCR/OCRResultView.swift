import SwiftUI

struct OCRResultView: View {
    @ObservedObject var viewModel: OCRViewModel
    let item: ClipboardHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Recognize Text")).font(.headline)
            switch viewModel.state {
            case .idle:
                Button(L10n.string("Recognize Text")) { Task { await viewModel.recognize(item: item) } }
            case .recognizing:
                HStack { ProgressView(); Text(L10n.string("Recognizing text…")) }
                    .accessibilityLabel(L10n.string("Recognizing text"))
            case .editing:
                TextEditor(text: $viewModel.editableText)
                    .font(.body.monospaced())
                    .frame(minHeight: 130)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)) }
                HStack {
                    Button(L10n.string("Cancel")) { viewModel.cancel() }
                    Spacer()
                    Button(L10n.string("Save")) { Task { await viewModel.save(item: item) } }
                        .buttonStyle(.borderedProminent)
                }
            case let .failed(error):
                Label(L10n.string(error.rawValue), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Button(L10n.string("Retry")) { Task { await viewModel.retry(item: item) } }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
