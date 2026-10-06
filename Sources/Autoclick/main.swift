import AppKit
import AutoclickCore

final class AppController: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let watcher = Watcher()
    private let regionPicker = RegionPicker()
    private var targetPicker: TargetPicker?
    private let settings = SettingsWindow()

    private let screenStatus = NSTextField(labelWithString: "")
    private let axStatus = NSTextField(labelWithString: "")
    private let preview = NSImageView()
    private let setupLabel = NSTextField(wrappingLabelWithString: "")
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let countLabel = NSTextField(labelWithString: "Clicks: 0")
    private var logView: NSTextView!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        Preferences.register()
        fileLog("launched")
        NSSetUncaughtExceptionHandler { e in fileLog("exception: \(e) \(e.callStackSymbols)") }
        buildMenu()
        buildWindow()
        refreshSetup()
        refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
        watcher.onLog = { [weak self] s in self?.appendLog(s) }
        watcher.onState = { [weak self] running, clicks in
            self?.startButton.title = running ? "Stop" : "Start"
            self?.countLabel.stringValue = "Clicks: \(clicks)"
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMain()
        return true
    }

    /// Makes the main window invisible so it stays out of captures. Ordering it out instead can
    /// leave the app with no windows, which macOS may treat as a reason to quit it.
    private func hideMain() {
        window.alphaValue = 0
        window.ignoresMouseEvents = true
    }

    private func showMain() {
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Layout

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Autoclick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    private func heading(_ title: String) -> NSTextField {
        let f = NSTextField(labelWithString: title)
        f.font = .boldSystemFont(ofSize: 13)
        return f
    }

    private func caption(_ s: String) -> NSTextField {
        let f = NSTextField(wrappingLabelWithString: s)
        f.textColor = .secondaryLabelColor
        f.font = .systemFont(ofSize: 11)
        f.preferredMaxLayoutWidth = 520
        return f
    }

    private func buildWindow() {
        let permGrid = NSGridView(views: [
            [NSTextField(labelWithString: "Screen Recording:"), screenStatus,
             NSStackView(views: [NSButton(title: "Grant…", target: self, action: #selector(grantScreen)),
                                 NSButton(title: "Relaunch", target: self, action: #selector(relaunchAction))])],
            [NSTextField(labelWithString: "Accessibility:"), axStatus,
             NSButton(title: "Grant…", target: self, action: #selector(grantAX))],
        ])
        permGrid.rowAlignment = .firstBaseline
        permGrid.columnSpacing = 12
        permGrid.column(at: 0).width = 120
        permGrid.column(at: 1).width = 110

        preview.imageScaling = .scaleProportionallyDown
        preview.imageFrameStyle = .grayBezel
        NSLayoutConstraint.activate([
            preview.heightAnchor.constraint(equalToConstant: 60),
            preview.widthAnchor.constraint(equalToConstant: 200),
        ])
        setupLabel.preferredMaxLayoutWidth = 300
        let setupRow = NSStackView(views: [preview, setupLabel])
        setupRow.alignment = .centerY
        setupRow.spacing = 12
        let setupButtons = NSStackView(views: [
            NSButton(title: "Capture Region & Target…", target: self, action: #selector(captureRegion)),
            NSButton(title: "Test", target: self, action: #selector(testMatch)),
            NSButton(title: "Settings…", target: self, action: #selector(openSettings)),
        ])

        startButton.target = self
        startButton.action = #selector(toggleRun)
        startButton.keyEquivalent = "\r"
        startButton.controlSize = .large
        let runRow = NSStackView(views: [startButton, countLabel])

        let scroll = NSTextView.scrollableTextView()
        logView = scroll.documentView as? NSTextView
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

        let stack = NSStackView(views: [
            heading("1. Permissions"), permGrid,
            caption("Click Grant… and turn on Autoclick in System Settings. Screen Recording takes effect only after you click Relaunch. Accessibility is needed to click."),
            heading("2. What to click"), setupRow, setupButtons,
            heading("3. Run"), runRow,
            caption("To stop: click Stop, or move the mouse into the top-left corner of the main screen."),
            scroll,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(18, after: stack.views[2])
        stack.setCustomSpacing(18, after: setupButtons)
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Autoclick"
        window.contentView = stack
        window.level = .floating // stays above the target window so Stop is always reachable
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("AutoclickMain")
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Permissions

    private func refreshPermissions() {
        screenStatus.stringValue = Permissions.screenRecording ? "✅ Granted" : "❌ Not granted"
        axStatus.stringValue = Permissions.accessibility ? "✅ Granted" : "❌ Not granted"
    }

    @objc private func grantScreen() {
        Permissions.requestScreenRecording()
        appendLog("Turn on Autoclick under Screen Recording, then click Relaunch.")
    }

    @objc private func grantAX() {
        Permissions.requestAccessibility()
        appendLog("Turn on Autoclick under Accessibility.")
    }

    @objc private func relaunchAction() { relaunch() }

    // MARK: Setup

    private func refreshSetup() {
        if let r = Preferences.region, let img = NSImage(contentsOf: Preferences.targetImageURL) {
            preview.image = img
            setupLabel.stringValue = "Watching \(Int(r.width))×\(Int(r.height)) pt at (\(Int(r.minX)), \(Int(r.minY))).\n" +
                "Capture again if the window you are watching moves or scrolls."
        } else {
            preview.image = nil
            setupLabel.stringValue = "Not set up yet. Get the target showing on screen, then click Capture."
        }
    }

    @objc private func captureRegion() {
        guard !watcher.running else { return }
        hideMain()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            regionPicker.pick { [self] r in
                guard let r, r.width >= 10, r.height >= 10 else { showMain(); return }
                let region = r.integral
                // Wait for the overlay to leave the screen before capturing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                    let shot = capture(region)
                    showMain()
                    guard let shot else {
                        appendLog("Screen capture failed. Check the Screen Recording permission.")
                        return
                    }
                    let picker = TargetPicker(capture: shot, pointSize: region.size)
                    targetPicker = picker
                    picker.run { [self] crop in
                        targetPicker = nil
                        guard let crop else { appendLog("Capture cancelled."); return }
                        let scale = Double(shot.width) / region.width
                        let size = CGSize(width: Double(crop.width) / scale, height: Double(crop.height) / scale)
                        savePNG(crop, to: Preferences.targetImageURL)
                        Preferences.region = region
                        Preferences.targetSize = size
                        refreshSetup()
                        appendLog("Saved target (\(Int(size.width))×\(Int(size.height)) pt).")
                        testMatch()
                    }
                }
            }
        }
    }

    @objc private func testMatch() {
        guard let finder = Preferences.makeFinder() else { appendLog("Nothing captured yet."); return }
        hideMain()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            let shot = capture(finder.region)
            showMain()
            guard let shot else { appendLog("Screen capture failed."); return }
            guard let m = finder.bestMatch(in: shot) else {
                appendLog("Test: the target image is larger than the region.")
                return
            }
            let found = m.score < finder.tolerance
            appendLog(String(format: "Test: best match score %.1f (tolerance %.0f) - target %@.",
                             m.score, finder.tolerance, found ? "FOUND" : "NOT found"))
        }
    }

    @objc private func openSettings() { settings.show() }

    @objc private func toggleRun() {
        if watcher.running { watcher.stop(); return }
        guard Permissions.accessibility else { appendLog("Grant Accessibility first."); return }
        guard Permissions.screenRecording else { appendLog("Grant Screen Recording first."); return }
        watcher.start()
    }

    private func appendLog(_ s: String) {
        fileLog(s)
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        logView.textStorage?.append(NSAttributedString(
            string: "[\(f.string(from: Date()))] \(s)\n",
            attributes: [.font: logView.font!, .foregroundColor: NSColor.labelColor]))
        logView.scrollToEndOfDocument(nil)
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.regular)
app.run()
