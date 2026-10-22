import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DragShakeMonitor()
    private var menuBar: MenuBarController?
    private var shelves: [ShelfController] = []
    /// Shelves opened by a shake that haven't received files yet; they vanish if the drag ends without a drop.
    private var pendingShelves: [ShelfController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(
            onNewShelf: { [weak self] in self?.openShelf(near: NSEvent.mouseLocation, pending: false) },
            onCloseAll: { [weak self] in self?.shelves.forEach { $0.close() } }
        )

        monitor.onShake = { [weak self] point in self?.openShelf(near: point, pending: true) }
        monitor.onMouseUp = { [weak self] in self?.dismissUnusedShelves() }
        monitor.start()
    }

    private func openShelf(near point: NSPoint, pending: Bool) {
        let shelf = ShelfController()
        shelf.onClosed = { [weak self] closed in
            self?.shelves.removeAll { $0 === closed }
            self?.pendingShelves.removeAll { $0 === closed }
        }
        shelves.append(shelf)
        if pending { pendingShelves.append(shelf) }
        shelf.show(near: point)
    }

    private func dismissUnusedShelves() {
        guard !pendingShelves.isEmpty else { return }
        let candidates = pendingShelves
        pendingShelves = []
        // The drop message can arrive just after the button is released, so wait a moment before checking.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for shelf in candidates where shelf.view.isEmpty {
                shelf.close()
            }
        }
    }
}
