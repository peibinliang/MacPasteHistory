import SwiftUI

struct KeywordHighlightedText: View {
    let text: String
    let terms: [String]

    var body: some View { Text(attributedText) }

    var attributedText: AttributedString {
        var result = AttributedString(text)
        for term in terms.filter({ $0.isEmpty == false }).sorted(by: { $0.count > $1.count }) {
            var searchStart = result.startIndex
            while let range = result[searchStart..<result.endIndex].range(of: term, options: .caseInsensitive) {
                result[range].backgroundColor = .yellow.opacity(0.35)
                searchStart = range.upperBound
            }
        }
        return result
    }
}
