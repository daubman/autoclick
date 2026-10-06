import AppKit
import AutoclickCore

/// A view that lets the user drag out a rectangle, optionally over an image.
final class SelectionView: NSView {
    var hint = ""
    var image: NSImage?
    var selection: NSRect? { didSet { needsDisplay = true } }
    /// Called on mouse-up with the selection, or nil on Esc.
    var onCommit: ((NSRect?) -> Void)?
    var onChange: ((NSRect?) -> Void)?
    private var dragStart: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

    var imageRect: NSRect { image.map { Geometry.aspectFit($0.size, in: bounds) } ?? bounds }

    override func draw(_ dirtyRect: NSRect) {
        if let image {
            NSColor.windowBackgroundColor.setFill(); bounds.fill()
            image.draw(in: imageRect)
        } else {
            NSColor.black.withAlphaComponent(0.3).setFill(); bounds.fill()
        }
        if let s = selection {
            if image == nil { NSColor.clear.setFill(); s.fill(using: .copy) }
            NSColor.systemRed.withAlphaComponent(0.12).setFill(); s.fill(using: .sourceOver)
            NSColor.systemRed.setStroke()
            let p = NSBezierPath(rect: s); p.lineWidth = 2; p.stroke()
        }
        if !hint.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 20), .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.6),
            ]
            let str = NSAttributedString(string: "  \(hint)  ", attributes: attrs)
            str.draw(at: NSPoint(x: (bounds.width - str.size().width) / 2, y: bounds.height - 120))
        }
    }

    override func mouseDown(with e: NSEvent) {
        dragStart = convert(e.locationInWindow, from: nil)
        selection = nil
    }

    override func mouseDragged(with e: NSEvent) {
        guard let dragStart else { return }
        var p = convert(e.locationInWindow, from: nil)
        if image != nil {
            let r = imageRect
            p.x = min(max(p.x, r.minX), r.maxX)
            p.y = min(max(p.y, r.minY), r.maxY)
        }
        selection = Geometry.rect(dragStart, p)
        onChange?(selection)
    }

    override func mouseUp(with e: NSEvent) {
        guard let s = selection, s.width >= 6, s.height >= 6 else {
            selection = nil; onChange?(nil); return
        }
        onCommit?(s)
    }

    override func keyDown(with e: NSEvent) {
        if e.keyCode == 53 { onCommit?(nil) } else { super.keyDown(with: e) } // Esc
    }
}

/// Dims every display and lets the user drag the region to watch.
final class RegionPicker {
    private var windows: [NSWindow] = []
    private var completion: ((CGRect?) -> Void)?

    /// Calls back with the region in global top-left points, or nil if cancelled.
    func pick(_ done: @escaping (CGRect?) -> Void) {
        completion = done
        let primaryHeight = NSScreen.screens[0].frame.height
        for screen in NSScreen.screens {
            let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = .screenSaver
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isReleasedWhenClosed = false
            let v = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            v.hint = "Drag around the area to watch, including the target. Esc cancels."
            v.onCommit = { [weak self, weak w] r in
                guard let self, let w else { return }
                self.finish(r.map { Geometry.flipped(w.convertToScreen($0), primaryScreenHeight: primaryHeight) })
            }
            w.contentView = v
            w.makeKeyAndOrderFront(nil)
            windows.append(w)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
    }

    private func finish(_ r: CGRect?) {
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        let c = completion
        completion = nil
        c?(r)
    }
}

/// Shows the captured region so the user can draw a box around the target.
final class TargetPicker: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let view = SelectionView()
    private let useButton = NSButton(title: "Use This Target", target: nil, action: nil)
    private let capture: CGImage
    private var completion: ((CGImage?) -> Void)?

    init(capture: CGImage, pointSize: CGSize) {
        self.capture = capture
        let s = min(1.0, 1000 / pointSize.width, 700 / pointSize.height)
        let viewSize = NSSize(width: max(360, pointSize.width * s), height: max(120, pointSize.height * s))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: viewSize.width + 40, height: viewSize.height + 100),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "Highlight the target to click"
        window.delegate = self
        window.isReleasedWhenClosed = false

        view.image = NSImage(cgImage: capture, size: pointSize)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.onChange = { [weak self] r in self?.useButton.isEnabled = r != nil }

        let label = NSTextField(wrappingLabelWithString:
            "Drag a box tightly around the target. Stay just inside its edge, so the box holds only the " +
            "target itself and no surrounding text that changes from one item to the next.")
        useButton.target = self
        useButton.action = #selector(use)
        useButton.keyEquivalent = "\r"
        useButton.isEnabled = false
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [NSView(), cancel, useButton])
        let stack = NSStackView(views: [label, view, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        window.contentView = stack
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: viewSize.width),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: viewSize.height),
            buttons.widthAnchor.constraint(equalTo: view.widthAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
    }

    /// Calls back with the cropped target image, or nil if cancelled.
    func run(_ done: @escaping (CGImage?) -> Void) {
        completion = done
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func use() {
        guard let sel = view.selection else { return }
        let crop = Geometry.cropRect(selection: sel, imageRect: view.imageRect,
                                     imagePixelSize: CGSize(width: capture.width, height: capture.height))
        finish(capture.cropping(to: crop))
    }

    @objc private func cancelAction() { finish(nil) }

    func windowWillClose(_ n: Notification) {
        let c = completion
        completion = nil
        c?(nil)
    }

    private func finish(_ img: CGImage?) {
        let c = completion
        completion = nil
        window.close()
        c?(img)
    }
}
