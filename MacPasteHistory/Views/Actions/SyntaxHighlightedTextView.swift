import AppKit
import SwiftUI

struct SyntaxHighlightedTextView: NSViewRepresentable {
    @Binding var text: String
    let syntax: ContentSyntax

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              textView.string != text else { return }
        textView.string = text
        applyHighlighting(to: textView)
    }

    private func applyHighlighting(to textView: NSTextView) {
        let attributed = NSMutableAttributedString(string: textView.string)
        let wholeRange = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: wholeRange)
        for token in ContentSyntaxHighlighter().tokens(for: textView.string, syntax: syntax) {
            let range = NSRange(token.range, in: textView.string)
            attributed.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
        }
        textView.textStorage?.setAttributedString(attributed)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) { _text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}
