import AppKit
import SwiftUI

struct HistoryImagePreview: View {
    let path: String?
    let size: NSSize

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var image: NSImage? {
        guard let path else { return nil }
        return NSImage(contentsOfFile: path)
    }
}
