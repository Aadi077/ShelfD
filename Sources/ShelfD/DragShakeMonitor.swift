import AppKit
import OSLog
import ShelfDCore

private let log = Logger(subsystem: "com.aadi.ShelfD", category: "monitor")

/// Watches the system-wide mouse state and reports when the user shakes the
/// cursor while dragging files. Polling needs no Accessibility permission.
final class DragShakeMonitor {
    /// Called with the cursor position (screen coordinates) when a shake is detected. At most once per drag.
    var onShake: ((NSPoint) -> Void)?
    /// Called whenever the left mouse button is released.
    var onMouseUp: (() -> Void)?
    /// Asked once when a file drag starts; returning true ignores shakes for that drag.
    var shouldIgnoreDrag: (() -> Bool)?

    var config: ShakeDetector.Config {
        get { detector.config }
        set { detector.config = newValue }
    }

    private let detector = ShakeDetector()
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var timer: Timer?

    private var buttonDown = false
    private var changeCountAtMouseDown = 0
    private var firedThisDrag = false
    /// Caches the file-drag check so the pasteboard is read once per drag, not every tick.
    private var checkedChangeCount = -1
    private var isFileDrag = false

    func start() {
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let down = NSEvent.pressedMouseButtons & 1 != 0

        if down && !buttonDown {
            buttonDown = true
            log.debug("Mouse down")
            changeCountAtMouseDown = dragPasteboard.changeCount
            firedThisDrag = false
            detector.reset()
        } else if !down && buttonDown {
            buttonDown = false
            log.debug("Mouse up")
            onMouseUp?()
            return
        }

        guard down, !firedThisDrag else { return }

        // A new drag session writes to the drag pasteboard, bumping its change count.
        let changeCount = dragPasteboard.changeCount
        guard changeCount != changeCountAtMouseDown else { return }
        if changeCount != checkedChangeCount {
            checkedChangeCount = changeCount
            isFileDrag = dragPasteboard.canReadObject(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) && !(shouldIgnoreDrag?() ?? false)
            log.info("Drag started (file drag: \(self.isFileDrag))")
        }
        guard isFileDrag else { return }

        let point = NSEvent.mouseLocation
        if detector.add(x: point.x, y: point.y, time: ProcessInfo.processInfo.systemUptime) {
            firedThisDrag = true
            log.info("Shake detected at \(point.x), \(point.y)")
            onShake?(point)
        }
    }
}
