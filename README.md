# ShelfD

A small macOS menu bar app for parking files. Start dragging files out of Finder and shake the cursor, and a little box pops up. Drop the files on it and the box becomes a floating shelf you can move anywhere. When you need the files, drag them back out of the shelf. An empty shelf closes itself.

Shelves only keep references to your files. Nothing gets copied or moved until you drag the files out somewhere.

## Usage

- **Shake to open a shelf.** While dragging files, shake the mouse quickly side to side and drop the files on the box that appears.
- **Move it.** Drag the shelf by its edge.
- **See what's on it.** Click the stack to expand it into a list, then drag single files out.
- **Empty it.** Drag the stack out to a folder, the Desktop, an app, and so on.
- **Close it.** Click the × in the corner.
- **Menu bar icon.** Use it to open an empty shelf, close every shelf, or quit.

## Build

You need macOS 14 or later and Xcode (or the Swift toolchain).

```bash
./scripts/build-app.sh
open build/ShelfD.app
```

Run the tests with `swift test`.

## Status

Early prototype. File-drag detection works. The full shake, drop and drag-out flow still needs testing by hand.
