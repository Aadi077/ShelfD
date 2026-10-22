import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DragShakeMonitor()
    private let preferences = Preferences.shared
    private let settings = SettingsWindowController()
    private var menuBar: MenuBarController?
    private var shelves: [ShelfController] = []
    /// Shelves opened by a shake that haven't received files yet; they vanish if the drag ends without a drop.
    private var pendingShelves: [ShelfController] = []
    private var sensitivityObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(
            onNewShelf: { [weak self] in self?.openShelf(near: NSEvent.mouseLocation, pending: false) },
            onCloseAll: { [weak self] in self?.shelves.forEach { $0.close() } },
            onSettings: { [weak self] in self?.settings.show() }
        )

        for saved in ShelfStore.load() {
            let shelf = ShelfController(items: saved.items, topLeft: saved.topLeft)
            track(shelf)
            shelf.show()
        }

        sensitivityObserver = preferences.$sensitivity.sink { [weak self] sensitivity in
            self?.monitor.config = sensitivity.config
        }
        monitor.shouldIgnoreDrag = { [weak self] in
            self?.preferences.isExcluded(NSWorkspace.shared.frontmostApplication) ?? false
        }
        monitor.onShake = { [weak self] point in self?.openShelf(near: point, pending: true) }
        monitor.onMouseUp = { [weak self] in self?.dismissUnusedShelves() }
        monitor.start()
    }

    private func openShelf(near point: NSPoint, pending: Bool) {
        let shelf = ShelfController()
        track(shelf)
        if pending { pendingShelves.append(shelf) }
        shelf.show(near: point)
    }

    private func track(_ shelf: ShelfController) {
        shelf.onClosed = { [weak self] closed in
            guard let self else { return }
            shelves.removeAll { $0 === closed }
            pendingShelves.removeAll { $0 === closed }
            ShelfStore.save(shelves)
        }
        shelf.onChange = { [weak self] in
            guard let self else { return }
            ShelfStore.save(shelves)
        }
        shelves.append(shelf)
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
