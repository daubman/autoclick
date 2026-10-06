import AppKit

final class SettingsWindow: NSObject {
    private var window: NSWindow?
    private var fields: [String: NSTextField] = [:]
    private var checkboxes: [String: NSButton] = [:]

    private let numberRows: [(key: String, label: String, help: String, isInt: Bool)] = [
        ("maxClicks", "Max clicks", "Stop after this many clicks.", true),
        ("interval", "Check every (s)", "How often to look for the target.", false),
        ("settleDelay", "Settle delay (s)", "Pause after the target appears before clicking.", false),
        ("retryAfter", "Click again after (s)", "If the target is still there this long after a click, click it again.", false),
        ("tolerance", "Match tolerance", "Mean pixel difference allowed, 0-255. Lower is stricter.", false),
    ]
    private let boolRows: [(key: String, label: String)] = [
        ("bringToFront", "Bring the target's app to the front before clicking"),
        ("restoreMouse", "Put the mouse back where it was after each click"),
    ]

    func show() {
        if window == nil { build() }
        load()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func build() {
        let grid = NSGridView()
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        for r in numberRows {
            let f = NSTextField(string: "")
            f.widthAnchor.constraint(equalToConstant: 80).isActive = true
            fields[r.key] = f
            let help = NSTextField(labelWithString: r.help)
            help.textColor = .secondaryLabelColor
            help.font = .systemFont(ofSize: 11)
            grid.addRow(with: [NSTextField(labelWithString: r.label + ":"), f, help])
        }
        for r in boolRows {
            let b = NSButton(checkboxWithTitle: r.label, target: nil, action: nil)
            checkboxes[r.key] = b
            grid.addRow(with: [NSGridCell.emptyContentView, b])
            grid.row(at: grid.numberOfRows - 1).mergeCells(in: NSRange(location: 1, length: 2))
        }
        grid.column(at: 0).xPlacement = .trailing

        let save = NSButton(title: "Save", target: self, action: #selector(saveAction))
        save.keyEquivalent = "\r"
        let reset = NSButton(title: "Restore Defaults", target: self, action: #selector(resetAction))
        let buttons = NSStackView(views: [reset, NSView(), save])

        let stack = NSStackView(views: [grid, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        buttons.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true

        let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Autoclick Settings"
        w.contentView = stack
        w.isReleasedWhenClosed = false
        window = w
    }

    private func load() {
        let d = Preferences.defaults
        for r in numberRows {
            fields[r.key]?.stringValue = r.isInt ? "\(d.integer(forKey: r.key))" : "\(d.double(forKey: r.key))"
        }
        for r in boolRows { checkboxes[r.key]?.state = d.bool(forKey: r.key) ? .on : .off }
    }

    @objc private func saveAction() {
        let d = Preferences.defaults
        for r in numberRows {
            let s = fields[r.key]?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
            if r.isInt, let v = Int(s), v > 0 { d.set(v, forKey: r.key) }
            if !r.isInt, let v = Double(s), v >= 0 { d.set(v, forKey: r.key) }
        }
        for r in boolRows { d.set(checkboxes[r.key]?.state == .on, forKey: r.key) }
        window?.close()
    }

    @objc private func resetAction() {
        for r in numberRows { Preferences.defaults.removeObject(forKey: r.key) }
        for r in boolRows { Preferences.defaults.removeObject(forKey: r.key) }
        load()
    }
}
