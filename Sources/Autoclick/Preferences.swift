import AppKit
import AutoclickCore

/// Settings and the saved target, persisted in UserDefaults and Application Support.
enum Preferences {
    static let defaults = UserDefaults.standard

    static let supportDir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Autoclick")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static let targetImageURL = supportDir.appendingPathComponent("target.png")
    static let captureURL = supportDir.appendingPathComponent("capture.png")
    static let logURL = supportDir.appendingPathComponent("autoclick.log")

    static func register() {
        let s = ClickLoopSettings()
        defaults.register(defaults: [
            "maxClicks": s.maxClicks, "interval": s.interval, "settleDelay": s.settleDelay,
            "retryAfter": s.retryAfter, "tolerance": 18.0, "restoreMouse": true, "bringToFront": true,
        ])
    }

    static var loopSettings: ClickLoopSettings {
        var s = ClickLoopSettings()
        s.maxClicks = max(1, defaults.integer(forKey: "maxClicks"))
        s.interval = defaults.double(forKey: "interval")
        s.settleDelay = defaults.double(forKey: "settleDelay")
        s.retryAfter = defaults.double(forKey: "retryAfter")
        return s
    }

    /// Mean pixel difference (0-255) below which the target counts as visible.
    static var tolerance: Double { defaults.double(forKey: "tolerance") }
    static var restoreMouse: Bool { defaults.bool(forKey: "restoreMouse") }
    static var bringToFront: Bool { defaults.bool(forKey: "bringToFront") }

    /// Region to watch, in global top-left screen points.
    static var region: CGRect? {
        get { defaults.string(forKey: "region").map { NSRectFromString($0) } }
        set { defaults.set(newValue.map { NSStringFromRect($0) }, forKey: "region") }
    }

    /// Size of the target image in screen points.
    static var targetSize: CGSize? {
        get { defaults.string(forKey: "targetSize").map { NSSizeFromString($0) } }
        set { defaults.set(newValue.map { NSStringFromSize($0) }, forKey: "targetSize") }
    }

    static func makeFinder() -> ButtonFinder? {
        guard let region, let targetSize, let img = loadImage(targetImageURL) else { return nil }
        return ButtonFinder(region: region, buttonImage: img, buttonSize: targetSize, tolerance: tolerance)
    }
}

/// Appends a timestamped line to the log file in Application Support.
func fileLog(_ s: String) {
    let line = "\(Date()) \(s)\n"
    if let h = try? FileHandle(forWritingTo: Preferences.logURL) {
        h.seekToEndOfFile()
        h.write(Data(line.utf8))
        try? h.close()
    } else {
        try? line.write(to: Preferences.logURL, atomically: true, encoding: .utf8)
    }
}
