import AppKit

/// The contents of a shelf: accepts dropped files, shows them as a stack (or a
/// list when expanded), and lets them be dragged back out.
final class ShelfView: NSView, NSDraggingSource {
    static let collapsedSize = NSSize(width: 150, height: 150)

    private(set) var items: [ShelfItem] = []
    /// Called when the view wants a different window size.
    var onSizeChange: ((NSSize) -> Void)?
    /// Called when the user drops the last item out, or clicks close.
    var onClose: (() -> Void)?

    private var expanded = false
    private var dropHighlight = false
    private var mouseDownEvent: NSEvent?
    private var mouseDownTarget: Target = .background
    private var dragStarted = false
    private var draggingOut: [ShelfItem] = []

    private enum Target: Equatable {
        case close, toggle, stack, row(Int), background
    }

    // Layout constants.
    private let closeRect = NSRect(x: 8, y: 8, width: 16, height: 16)
    private let stackRect = NSRect(x: 25, y: 22, width: 100, height: 88)
    private let expandedWidth: CGFloat = 260
    private let headerHeight: CGFloat = 32
    private let rowHeight: CGFloat = 28
    private let maxRows = 10

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var isEmpty: Bool { items.isEmpty }

    // MARK: - Items

    func add(_ urls: [URL]) {
        for url in urls {
            let item = ShelfItem(url: url)
            if !items.contains(item) { items.append(item) }
        }
        itemsChanged()
    }

    private func remove(_ removed: [ShelfItem]) {
        items.removeAll { removed.contains($0) }
        itemsChanged()
    }

    /// Drops items whose files have been deleted.
    private func prune() {
        let before = items.count
        items.removeAll { $0.url == nil }
        if items.count != before { itemsChanged() }
    }

    private func itemsChanged() {
        if items.count <= 1 { expanded = false }
        needsDisplay = true
        onSizeChange?(preferredSize)
    }

    private var visibleRowCount: Int { min(items.count, maxRows) }

    private var preferredSize: NSSize {
        guard expanded else { return Self.collapsedSize }
        let extraRow: CGFloat = items.count > maxRows ? 1 : 0
        return NSSize(
            width: expandedWidth,
            height: headerHeight + (CGFloat(visibleRowCount) + extraRow) * rowHeight + 8
        )
    }

    private var toggleRect: NSRect {
        NSRect(x: bounds.width - 24, y: 8, width: 16, height: 16)
    }

    private func rowRect(_ index: Int) -> NSRect {
        NSRect(x: 6, y: headerHeight + CGFloat(index) * rowHeight, width: bounds.width - 12, height: rowHeight)
    }

    private func target(at point: NSPoint) -> Target {
        if closeRect.insetBy(dx: -4, dy: -4).contains(point) { return .close }
        if isEmpty { return .background }
        if expanded {
            if toggleRect.insetBy(dx: -4, dy: -4).contains(point) { return .toggle }
            for i in 0..<visibleRowCount where rowRect(i).contains(point) { return .row(i) }
            return .background
        }
        return stackRect.contains(point) ? .stack : .background
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        if isEmpty {
            drawEmptyState()
        } else if expanded {
            drawList()
        } else {
            drawStack()
        }
        drawCloseButton()
    }

    private func drawEmptyState() {
        let box = bounds.insetBy(dx: 10, dy: 10).offsetBy(dx: 0, dy: 8).insetBy(dx: 0, dy: 8)
        let path = NSBezierPath(roundedRect: box, xRadius: 10, yRadius: 10)
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        (dropHighlight ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor).setStroke()
        if dropHighlight {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            path.fill()
        }
        path.stroke()
        drawText("Drop files here", in: NSRect(x: box.minX, y: box.midY - 9, width: box.width, height: 18),
                 color: dropHighlight ? .controlAccentColor : .secondaryLabelColor, size: 12)
    }

    private func drawStack() {
        if dropHighlight {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 11, yRadius: 11).fill()
        }

        let shown = Array(items.prefix(3))
        let iconSize: CGFloat = 64
        let center = NSPoint(x: stackRect.midX, y: stackRect.midY)
        // Back-to-front: the first item is drawn last, on top and upright.
        let fan: [(angle: CGFloat, dx: CGFloat)] = [(0, 0), (-8, -12), (8, 12)]
        for index in stride(from: shown.count - 1, through: 0, by: -1) {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: center.x + fan[index].dx, yBy: center.y)
            transform.rotate(byDegrees: fan[index].angle)
            transform.concat()
            shown[index].icon.draw(
                in: NSRect(x: -iconSize / 2, y: -iconSize / 2, width: iconSize, height: iconSize),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
            )
            NSGraphicsContext.restoreGraphicsState()
        }

        let label = items.count == 1 ? items[0].name : "\(items.count) files"
        drawText(label, in: NSRect(x: 8, y: 116, width: bounds.width - 16, height: 18), color: .labelColor, size: 12)
    }

    private func drawList() {
        drawText("\(items.count) files", in: NSRect(x: 30, y: 8, width: bounds.width - 60, height: 18),
                 color: .labelColor, size: 12, weight: .semibold)
        drawChevron(in: toggleRect)

        for i in 0..<visibleRowCount {
            let rect = rowRect(i)
            items[i].icon.draw(
                in: NSRect(x: rect.minX + 4, y: rect.minY + 4, width: 20, height: 20),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
            )
            drawText(items[i].name, in: NSRect(x: rect.minX + 30, y: rect.minY + 6, width: rect.width - 34, height: 18),
                     color: .labelColor, size: 12, alignment: .left)
        }
        if items.count > maxRows {
            let rect = rowRect(maxRows)
            drawText("+ \(items.count - maxRows) more", in: NSRect(x: rect.minX + 30, y: rect.minY + 6, width: rect.width - 34, height: 18),
                     color: .secondaryLabelColor, size: 12, alignment: .left)
        }
    }

    private func drawCloseButton() {
        NSColor.secondaryLabelColor.withAlphaComponent(0.25).setFill()
        NSBezierPath(ovalIn: closeRect).fill()
        let cross = NSBezierPath()
        let r = closeRect.insetBy(dx: 5, dy: 5)
        cross.move(to: NSPoint(x: r.minX, y: r.minY))
        cross.line(to: NSPoint(x: r.maxX, y: r.maxY))
        cross.move(to: NSPoint(x: r.maxX, y: r.minY))
        cross.line(to: NSPoint(x: r.minX, y: r.maxY))
        cross.lineWidth = 1.5
        cross.lineCapStyle = .round
        NSColor.secondaryLabelColor.setStroke()
        cross.stroke()
    }

    private func drawChevron(in rect: NSRect) {
        // Points up: click to collapse the list back into a stack.
        let r = rect.insetBy(dx: 4, dy: 5)
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: r.minX, y: r.maxY))
        chevron.line(to: NSPoint(x: r.midX, y: r.minY))
        chevron.line(to: NSPoint(x: r.maxX, y: r.maxY))
        chevron.lineWidth = 1.5
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        NSColor.secondaryLabelColor.setStroke()
        chevron.stroke()
    }

    private func drawText(_ text: String, in rect: NSRect, color: NSColor, size: CGFloat,
                          weight: NSFont.Weight = .regular, alignment: NSTextAlignment = .center) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingMiddle
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    // MARK: - Mouse: move the window, expand, or drag files out

    override func mouseDown(with event: NSEvent) {
        prune()
        mouseDownEvent = event
        dragStarted = false
        mouseDownTarget = target(at: convert(event.locationInWindow, from: nil))
        if mouseDownTarget == .background {
            // Runs its own tracking loop until the mouse is released.
            window?.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted, let down = mouseDownEvent else { return }
        let start = down.locationInWindow, now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }

        switch mouseDownTarget {
        case .stack:
            beginDraggingOut(items, event: down)
        case .row(let i) where i < items.count:
            beginDraggingOut([items[i]], event: down)
        default:
            return
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownEvent = nil }
        guard !dragStarted, target(at: convert(event.locationInWindow, from: nil)) == mouseDownTarget else { return }
        switch mouseDownTarget {
        case .close:
            onClose?()
        case .stack where items.count > 1, .toggle:
            expanded.toggle()
            needsDisplay = true
            onSizeChange?(preferredSize)
        default:
            break
        }
    }

    private func beginDraggingOut(_ outgoing: [ShelfItem], event: NSEvent) {
        let present = outgoing.compactMap { item in item.url.map { (item, $0) } }
        guard !present.isEmpty else { prune(); return }

        dragStarted = true
        draggingOut = present.map(\.0)
        let origin = convert(event.locationInWindow, from: nil)
        let dragItems = present.enumerated().map { index, pair -> NSDraggingItem in
            let dragItem = NSDraggingItem(pasteboardWriter: pair.1 as NSURL)
            let offset = CGFloat(min(index, 4)) * 4
            dragItem.setDraggingFrame(
                NSRect(x: origin.x - 32 + offset, y: origin.y - 32 + offset, width: 64, height: 64),
                contents: pair.0.icon
            )
            return dragItem
        }
        let session = beginDraggingSession(with: dragItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move, .generic, .link, .delete]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let outgoing = draggingOut
        draggingOut = []
        guard !operation.isEmpty else { return }
        remove(outgoing)
        if isEmpty { onClose?() }
    }

    // MARK: - NSDraggingDestination

    private func acceptedOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        if (sender.draggingSource as? ShelfView) === self { return [] }
        let hasFiles = sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        )
        guard hasFiles else { return [] }
        // We only keep a reference, so prefer an operation that doesn't imply copying.
        let mask = sender.draggingSourceOperationMask
        return [NSDragOperation.generic, .link, .copy, .move].first { mask.contains($0) } ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = acceptedOperation(for: sender)
        dropHighlight = !operation.isEmpty
        needsDisplay = true
        return operation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptedOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropHighlight = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropHighlight = false
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        guard !urls.isEmpty else { needsDisplay = true; return false }
        add(urls)
        return true
    }
}
