import AppKit

/// Owns one shelf's panel and view.
final class ShelfController {
    let panel: ShelfPanel
    let view: ShelfView
    /// Called once the shelf has closed, so the owner can forget it.
    var onClosed: ((ShelfController) -> Void)?

    init() {
        panel = ShelfPanel(contentSize: ShelfView.collapsedSize)
        view = ShelfView(frame: NSRect(origin: .zero, size: ShelfView.collapsedSize))
        view.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(view)

        view.onSizeChange = { [weak self] size in self?.panel.resize(to: size) }
        view.onClose = { [weak self] in self?.close() }
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
