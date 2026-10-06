import AppKit
import AutoclickCore

/// Runs the click loop on a background thread against the real screen and mouse.
final class Watcher: ClickEnvironment {
    var onLog: (String) -> Void = { _ in }
    var onState: (_ running: Bool, _ clicks: Int) -> Void = { _, _ in }
    private(set) var running = false
    private var cancelled = false
    private var finder: ButtonFinder!
    private var restoreMouse = true, bringToFront = true

    func stop() { cancelled = true }

    func start() {
        guard !running else { return }
        guard let f = Preferences.makeFinder() else { onLog("Capture a region and target first."); return }
        finder = f
        restoreMouse = Preferences.restoreMouse
        bringToFront = Preferences.bringToFront
        let settings = Preferences.loopSettings
        cancelled = false
        running = true
        onState(true, 0)
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let outcome = runClickLoop(settings, self)
            DispatchQueue.main.async {
                self.running = false
                switch outcome {
                case .finished(let n): self.onState(false, n)
                case .stopped(let n): self.onLog("Stopped after \(n) clicks."); self.onState(false, n)
                }
            }
        }
    }

    // MARK: ClickEnvironment

    func locate() -> CGPoint? { capture(finder.region).flatMap(finder.locate(in:)) }

    func click(at point: CGPoint) {
        let before = mouseLocation()
        if bringToFront { activateApp(at: point) }
        Autoclick.click(at: point)
        if restoreMouse { CGWarpMouseCursorPosition(before) }
    }

    func sleep(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    func shouldStop() -> Bool {
        let m = mouseLocation()
        if m.x < 5 && m.y < 5 && !cancelled {
            cancelled = true
            log("Mouse in the top-left corner - stopping.")
        }
        return cancelled
    }

    func log(_ message: String) { DispatchQueue.main.async { self.onLog(message) } }

    func didClick(count: Int) { DispatchQueue.main.async { self.onState(true, count) } }
}
