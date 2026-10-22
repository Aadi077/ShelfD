import AppKit

/// The menu bar icon and its menu.
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onNewShelf: () -> Void
    private let onCloseAll: () -> Void
    private let onSettings: () -> Void

    init(onNewShelf: @escaping () -> Void, onCloseAll: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onNewShelf = onNewShelf
        self.onCloseAll = onCloseAll
        self.onSettings = onSettings
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "ShelfD")

        let menu = NSMenu()
        menu.addItem(withTitle: "Shake while dragging files to make a shelf", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(item("New Empty Shelf", #selector(newShelf), key: "n"))
        menu.addItem(item("Close All Shelves", #selector(closeAll), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(withTitle: "Quit ShelfD", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func newShelf() { onNewShelf() }
    @objc private func closeAll() { onCloseAll() }
    @objc private func openSettings() { onSettings() }
}
