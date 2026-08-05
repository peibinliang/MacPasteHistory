import AppKit

@MainActor
final class HistoryPanelWindow: NSPanel {
    static let defaultSize = NSSize(width: 760, height: 520)
    static let defaultTopInset: CGFloat = 12
    static let cornerRadius: CGFloat = 24

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configureOverlayBehavior()
    }

    func positionOnActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let activeScreen else {
            return
        }
        setFrame(
            Self.topCenteredFrame(
                panelSize: frame.size,
                screenFrame: activeScreen.visibleFrame,
                topInset: Self.defaultTopInset
            ),
            display: false
        )
    }

    static func topCenteredFrame(
        panelSize: NSSize,
        screenFrame: NSRect,
        topInset: CGFloat
    ) -> NSRect {
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height - topInset
        )
        return NSRect(origin: origin, size: panelSize)
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    private func configureOverlayBehavior() {
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
        isMovable = false
        isMovableByWindowBackground = false
    }
}
