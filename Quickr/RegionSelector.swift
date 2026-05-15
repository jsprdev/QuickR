import AppKit
import Carbon.HIToolbox

struct SelectionResult {
    let screen: NSScreen
    /// Rect in global AppKit coordinates (bottom-left origin, union of all screens).
    let rect: CGRect
}

@MainActor
final class RegionSelector {
    private var windows: [SelectionWindow] = []
    var onComplete: ((SelectionResult?) -> Void)?

    func present() {
        windows = NSScreen.screens.map { screen in
            let window = SelectionWindow(screen: screen)
            window.onFinish = { [weak self] result in self?.complete(result) }
            return window
        }
        windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func complete(_ result: SelectionResult?) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onComplete?(result)
    }
}

private final class SelectionWindow: NSWindow {
    var onFinish: ((SelectionResult?) -> Void)?
    private let screenRef: NSScreen

    init(screen: NSScreen) {
        self.screenRef = screen
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let view = SelectionView()
        view.onConfirm = { [weak self] localRect in
            guard let self else { return }
            let global = CGRect(
                x: localRect.origin.x + screen.frame.origin.x,
                y: localRect.origin.y + screen.frame.origin.y,
                width: localRect.width,
                height: localRect.height
            )
            self.onFinish?(SelectionResult(screen: screen, rect: global))
        }
        view.onCancel = { [weak self] in self?.onFinish?(nil) }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            onFinish?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish?(nil)
    }
}

private final class SelectionView: NSView {
    var onConfirm: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragOrigin: CGPoint?
    private var currentRect: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragOrigin else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, p.x),
            y: min(start.y, p.y),
            width: abs(p.x - start.x),
            height: abs(p.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragOrigin = nil
            currentRect = .zero
            needsDisplay = true
        }
        guard currentRect.width > 4, currentRect.height > 4 else {
            onCancel?()
            return
        }
        onConfirm?(currentRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSColor.black.withAlphaComponent(0.22)
        dim.setFill()

        if currentRect == .zero {
            dirtyRect.fill()
            return
        }

        // Draw four strips around the selection rather than a full fill so the
        // selected region stays visually clear
        let b = bounds
        let r = currentRect
        let strips: [CGRect] = [
            CGRect(x: b.minX, y: r.maxY, width: b.width, height: max(0, b.maxY - r.maxY)),
            CGRect(x: b.minX, y: b.minY, width: b.width, height: max(0, r.minY - b.minY)),
            CGRect(x: b.minX, y: r.minY, width: max(0, r.minX - b.minX), height: r.height),
            CGRect(x: r.maxX, y: r.minY, width: max(0, b.maxX - r.maxX), height: r.height)
        ]
        strips.forEach { $0.fill() }

        NSColor.white.setStroke()
        let path = NSBezierPath(rect: currentRect)
        path.lineWidth = 1
        path.stroke()
    }
}
