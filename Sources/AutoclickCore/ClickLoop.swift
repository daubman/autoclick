import CoreGraphics

/// The side effects the click loop needs. The app supplies real screen capture and mouse events;
/// tests supply a scripted fake.
public protocol ClickEnvironment: AnyObject {
    /// Center of the target if it is visible right now.
    func locate() -> CGPoint?
    func click(at point: CGPoint)
    func sleep(_ seconds: Double)
    /// Checked between every step. Return true to stop.
    func shouldStop() -> Bool
    func log(_ message: String)
    func didClick(count: Int)
}

public struct ClickLoopSettings: Equatable {
    /// Stop after this many clicks.
    public var maxClicks = 50
    /// Seconds between screen checks.
    public var interval = 0.5
    /// Pause after the target appears before clicking, so the page can finish rendering.
    public var settleDelay = 0.4
    /// If the target is still visible this long after a click, assume the click was missed.
    public var retryAfter = 15.0
    /// Log a "still waiting" line this often while the target is absent.
    public var waitingLogEvery = 30.0

    public init() {}
}

public enum ClickLoopOutcome: Equatable {
    case finished(clicks: Int)
    case stopped(clicks: Int)
}

/// Clicks the target each time it appears.
///
/// Each cycle: wait for the target, let it settle, confirm it is still there, click it, then wait
/// for it to disappear so the same instance is never clicked twice. If it does not disappear within
/// `retryAfter`, the next cycle clicks it again.
public func runClickLoop(_ settings: ClickLoopSettings, _ env: ClickEnvironment) -> ClickLoopOutcome {
    let interval = max(0.05, settings.interval)
    var clicks = 0
    env.log("Watching - up to \(settings.maxClicks) clicks.")

    while clicks < settings.maxClicks {
        // Wait for the target to appear.
        var waited = 0.0, lastWaitLog = 0.0
        while env.locate() == nil {
            if env.shouldStop() { return .stopped(clicks: clicks) }
            env.sleep(interval)
            waited += interval
            if waited - lastWaitLog >= settings.waitingLogEvery {
                lastWaitLog = waited
                env.log("Still waiting for the target (\(Int(waited))s)...")
            }
        }
        if env.shouldStop() { return .stopped(clicks: clicks) }

        if settings.settleDelay > 0 { env.sleep(settings.settleDelay) }
        if env.shouldStop() { return .stopped(clicks: clicks) }
        guard let point = env.locate() else { continue } // vanished while settling

        env.click(at: point)
        clicks += 1
        env.didClick(count: clicks)
        env.log("Click \(clicks)/\(settings.maxClicks) at (\(Int(point.x)), \(Int(point.y)))")
        if clicks >= settings.maxClicks { break }

        // Wait for it to go away.
        var elapsed = 0.0, gone = false
        while elapsed < settings.retryAfter {
            env.sleep(interval)
            elapsed += interval
            if env.shouldStop() { return .stopped(clicks: clicks) }
            if env.locate() == nil { gone = true; break }
        }
        if !gone { env.log("Target still showing after \(Int(settings.retryAfter))s - clicking again.") }
    }
    env.log("Done: \(clicks) clicks.")
    return .finished(clicks: clicks)
}
