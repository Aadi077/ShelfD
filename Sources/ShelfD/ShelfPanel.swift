import AppKit

/// A small borderless window that floats above everything, on every Space,
/// without stealing focus from the app the user is working in.
final class ShelfPanel: NSPanel {
    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))
        background.material = .popover
        background.state = .active
        background.blendingMode = .behindWindow
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]
        contentView = background
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Positions the panel beside `point` (screen coordinates) so it doesn't sit
    /// under the cursor, keeping it on the visible part of that screen.
    func place(near point: NSPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = frame.size
        let gap: CGFloat = 40

        var origin = NSPoint(x: point.x + gap, y: point.y - size.height / 2)
        if origin.x + size.width > visible.maxX {
            origin.x = point.x - gap - size.width
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        setFrameOrigin(origin)
    }

    /// Resizes the panel while keeping its top-left corner fixed.
    func resize(to size: NSSize) {
        guard size != frame.size else { return }
        var newFrame = frame
        newFrame.origin.y = frame.maxY - size.height
        newFrame.size = size
        setFrame(newFrame, display: true, animate: true)
    }
}
