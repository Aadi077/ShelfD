import AppKit

/// A file held on a shelf. Stores a file reference URL so the item keeps
/// pointing at the file if it is renamed or moved on the same volume.
struct ShelfItem: Equatable {
    private let reference: URL
    private let originalURL: URL

    init(url: URL) {
        originalURL = url
        reference = (url as NSURL).fileReferenceURL() ?? url
    }

    /// The file's current path, or nil if it no longer exists.
    var url: URL? {
        let resolved = (reference as NSURL).filePathURL ?? originalURL
        return FileManager.default.fileExists(atPath: resolved.path) ? resolved : nil
    }

    var name: String {
        (url ?? originalURL).lastPathComponent
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: (url ?? originalURL).path)
    }

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool {
        lhs.reference == rhs.reference
    }
}
