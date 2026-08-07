import AppKit

enum HistoryPanelLayoutMode: Equatable {
    case expanded
    case overlay
}

@MainActor
final class HistoryPanelWindow: NSPanel {
    static let defaultSize = NSSize(width: 880, height: 620)
    static let expandedPreferredWidth: CGFloat = 1_240
    static let minimumScreenSideInset: CGFloat = 24
    static let defaultTopInset: CGFloat = 12
    static let cornerRadius: CGFloat = 24
    nonisolated static let keyboardFocusEffectDisabled = true

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

    static func layoutMode(availableWidth: CGFloat) -> HistoryPanelLayoutMode {
        availableWidth >= expandedPreferredWidth + minimumScreenSideInset * 2 ? .expanded : .overlay
    }

    static func panelSize(for mode: HistoryPanelLayoutMode, screenVisibleFrame: NSRect) -> NSSize {
        let preferredWidth = mode == .expanded ? expandedPreferredWidth : defaultSize.width
        let maximumWidth = max(0, screenVisibleFrame.width - minimumScreenSideInset * 2)
        return NSSize(
            width: min(preferredWidth, maximumWidth),
            height: min(defaultSize.height, screenVisibleFrame.height)
        )
    }

    func resizeForActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let activeScreen else { return }
        let mode = Self.layoutMode(availableWidth: activeScreen.visibleFrame.width)
        setContentSize(Self.panelSize(for: mode, screenVisibleFrame: activeScreen.visibleFrame))
    }

    override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            let shouldHide = Self.shouldHideAfterResigningKey(
                hasAttachedSheet: attachedSheet != nil,
                isKeyWindow: isKeyWindow
            )
            if shouldHide {
                orderOut(nil)
            }
        }
    }

    static func shouldHideAfterResigningKey(
        hasAttachedSheet: Bool,
        isKeyWindow: Bool
    ) -> Bool {
        hasAttachedSheet == false && isKeyWindow == false
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
