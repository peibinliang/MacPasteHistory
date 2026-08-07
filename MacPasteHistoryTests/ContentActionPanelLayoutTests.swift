import AppKit
import SwiftUI
import XCTest
@testable import MacPasteHistory

@MainActor
final class ContentActionPanelLayoutTests: XCTestCase {
    func testLayoutMode_usesExpandedOnlyWhenSideInsetsFit() {
        XCTAssertEqual(HistoryPanelWindow.layoutMode(availableWidth: 1_287), .overlay)
        XCTAssertEqual(HistoryPanelWindow.layoutMode(availableWidth: 1_288), .expanded)
    }

    func testPanelSize_usesPreferredExpandedWidthAndDefaultOverlayWidth() {
        let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)

        XCTAssertEqual(HistoryPanelWindow.panelSize(for: .expanded, screenVisibleFrame: screen), NSSize(width: 1_240, height: 620))
        XCTAssertEqual(HistoryPanelWindow.panelSize(for: .overlay, screenVisibleFrame: screen), HistoryPanelWindow.defaultSize)
    }

    func testActionPaletteAndSuccessAndFailurePreviewsRender() {
        let viewModel = ContentActionPanelViewModel()
        let item = makeItem(text: "1700000000", detectedType: .timestamp)
        viewModel.present(for: item)
        render(ContentActionCommandPalette(viewModel: viewModel))

        viewModel.execute(actionID: ContentActionID(rawValue: "timestamp.convert"))
        XCTAssertTrue(viewModel.hasUsableResult)
        render(preview(viewModel))

        viewModel.present(for: makeItem(text: "bad%2"))
        viewModel.execute(actionID: ContentActionID(rawValue: "url.decode"))
        XCTAssertEqual(viewModel.failureMessageKey, "content-action.url.invalid")
        render(preview(viewModel))
    }

    private func preview(_ viewModel: ContentActionPanelViewModel) -> ContentActionPreviewView {
        ContentActionPreviewView(
            actionViewModel: viewModel,
            copyAction: { _, _ in },
            pasteAction: { _, _ in },
            saveAction: { _ in },
            backAction: {},
            closeAction: {}
        )
    }

    private func render<Content: View>(_ content: Content) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 640)
        XCTAssertEqual(hostingView.frame.size, NSSize(width: 520, height: 640))
    }

    private func makeItem(text: String, detectedType: DetectedContentType? = nil) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: 99,
            contentType: .text,
            textContent: text,
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: nil,
            sourceBundleID: nil,
            contentHash: "render-test",
            textLength: text.count,
            fileSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageFormat: nil,
            isFavorite: false,
            isSensitive: false,
            createdAt: .distantPast,
            updatedAt: .distantPast,
            detectedType: detectedType
        )
    }
}
