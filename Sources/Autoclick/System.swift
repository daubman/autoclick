import AppKit
import ApplicationServices
import AutoclickCore

// Screen capture, mouse events and permissions.

/// Captures a rect in global top-left screen points. Uses the system `screencapture` tool, which
/// handles every display and scale factor and runs under this app's Screen Recording permission.
func capture(_ r: CGRect, to url: URL = Preferences.captureURL) -> CGImage? {
    try? FileManager.default.removeItem(at: url)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = ["-x", "-t", "png", "-R",
                   "\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))", url.path]
    do { try p.run() } catch { return nil }
    p.waitUntilExit()
    return loadImage(url)
}

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func savePNG(_ img: CGImage, to url: URL) {
    guard let dst = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dst, img, nil)
    CGImageDestinationFinalize(dst)
}

/// Mouse location in global top-left screen points.
func mouseLocation() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }

/// Brings the app that owns the window under `p` to the front. Browsers ignore synthetic clicks on
/// background windows, so this has to happen before clicking. Returns that app's name.
@discardableResult
func activateApp(at p: CGPoint) -> String? {
    guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return nil }
    let me = ProcessInfo.processInfo.processIdentifier
    for w in info { // front to back
        guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
              let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid != me,
              let b = w[kCGWindowBounds as String] as? NSDictionary,
              let r = CGRect(dictionaryRepresentation: b), r.contains(p) else { continue }
        let app = NSRunningApplication(processIdentifier: pid)
        if app?.isActive == false {
            app?.activate()
            usleep(300_000)
        }
        return app?.localizedName
    }
    return nil
}

/// Posts a left click. Browsers need the click-state field set and a short hover first.
func click(at p: CGPoint) {
    let src = CGEventSource(stateID: .hidSystemState)
    func post(_ type: CGEventType) {
        let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
        e?.setIntegerValueField(.mouseEventClickState, value: 1)
        e?.post(tap: .cghidEventTap)
    }
    post(.mouseMoved)
    usleep(150_000)
    post(.leftMouseDown)
    usleep(80_000)
    post(.leftMouseUp)
    usleep(150_000)
}

enum Permissions {
    /// Note: macOS only reports a newly granted Screen Recording permission after a relaunch.
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }
    static var accessibility: Bool { AXIsProcessTrusted() && CGPreflightPostEventAccess() }

    static func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
    }

    static func requestAccessibility() {
        let o = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(o) {
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    private static func open(_ s: String) { NSWorkspace.shared.open(URL(string: s)!) }
}

/// Quits and reopens the app. A detached shell does the reopen after this process has exited.
func relaunch() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", "sleep 1; /usr/bin/open -n \"$0\"", Bundle.main.bundlePath]
    try? p.run()
    NSApp.terminate(nil)
}
