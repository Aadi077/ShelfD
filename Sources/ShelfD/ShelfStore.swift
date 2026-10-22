import AppKit

/// Saves open shelves to Application Support so they come back after a relaunch.
enum ShelfStore {
    struct SavedShelf: Codable {
        var x: Double
        var y: Double
        var bookmarks: [Data]
    }

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ShelfD/shelves.json")
    }

    static func save(_ shelves: [ShelfController]) {
        let saved = shelves.compactMap { shelf -> SavedShelf? in
            let bookmarks = shelf.view.items.compactMap(\.bookmark)
            guard !bookmarks.isEmpty else { return nil }
            return SavedShelf(x: shelf.topLeft.x, y: shelf.topLeft.y, bookmarks: bookmarks)
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(saved).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("ShelfD: couldn't save shelves: \(error)")
        }
    }

    /// Shelves saved last time, minus any files that no longer exist.
    static func load() -> [(items: [ShelfItem], topLeft: NSPoint)] {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([SavedShelf].self, from: data) else { return [] }
        return saved.compactMap { shelf in
            let items = shelf.bookmarks.compactMap(ShelfItem.init(bookmark:))
            return items.isEmpty ? nil : (items, NSPoint(x: shelf.x, y: shelf.y))
        }
    }
}
