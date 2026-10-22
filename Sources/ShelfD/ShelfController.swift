import AppKit

/// Owns one shelf's panel and view.
final class ShelfController {
    let panel: ShelfPanel
    let view: ShelfView
    /// Called once the shelf has closed, so the owner can forget it.
    var onClosed: ((ShelfController) -> Void)?
    /// Called when the shelf's items or position change, so the owner can save it.
    var onChange: (() -> Void)?
    private var moveObserver: NSObjectProtocol?

    init() {
        panel = ShelfPanel(contentSize: ShelfView.collapsedSize)
        view = ShelfView(frame: NSRect(origin: .zero, size: ShelfView.collapsedSize))
        view.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(view)

        view.onSizeChange = { [weak self] size in self?.panel.resize(to: size) }
        view.onClose = { [weak self] in self?.close() }
        view.onItemsChange = { [weak self] in self?.onChange?() }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.onChange?() }
    }

    deinit {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
    }

    /// Recreates a saved shelf with its top-left corner at `topLeft` (screen coordinates).
    convenience init(items: [ShelfItem], topLeft: NSPoint) {
        self.init()
        view.restore(items)
        let size = panel.frame.size
        var origin = NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        // If the screen it was on is gone, bring it back onto the main screen.
        let frame = NSRect(origin: origin, size: size)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }),
           let visible = NSScreen.main?.visibleFrame {
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        }
        panel.setFrameOrigin(origin)
    }

    var topLeft: NSPoint {
        NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func show(near point: NSPoint) {
        panel.place(near: point)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [self] in
            panel.orderOut(nil)
            onClosed?(self)
        })
    }
}
