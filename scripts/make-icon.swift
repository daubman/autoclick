// Draws the app icon and writes Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift
//
// Requires iconutil, which ships with macOS.
import AppKit

func drawIcon(size s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let u = s / 1024 // design on a 1024 grid

    // Rounded-square tile with the standard macOS margin and a soft shadow.
    let tile = NSRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * u, yRadius: 185 * u)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 24 * u,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    tilePath.fill()
    ctx.restoreGState()
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.55, blue: 1.00, alpha: 1),
               ending: NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.70, alpha: 1))!
        .draw(in: tilePath, angle: -90)

    // Target rings around the button center.
    let center = NSPoint(x: 470 * u, y: 560 * u)
    for (r, a) in [(300.0, 0.10), (225.0, 0.16)] {
        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - r * u, y: center.y - r * u, width: 2 * r * u, height: 2 * r * u))
        ring.lineWidth = 18 * u
        NSColor.white.withAlphaComponent(a).setStroke()
        ring.stroke()
    }

    // Pill button.
    let button = NSRect(x: center.x - 230 * u, y: center.y - 78 * u, width: 460 * u, height: 156 * u)
    let buttonPath = NSBezierPath(roundedRect: button, xRadius: 78 * u, yRadius: 78 * u)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 20 * u,
                  color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.white.setFill()
    buttonPath.fill()
    ctx.restoreGState()
    // Label bar on the button.
    NSColor(calibratedRed: 0.15, green: 0.40, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: center.x - 120 * u, y: center.y - 18 * u, width: 240 * u, height: 36 * u),
                 xRadius: 18 * u, yRadius: 18 * u).fill()

    // Click burst at the pointer tip.
    let tip = NSPoint(x: 590 * u, y: 520 * u)
    let burst = NSBezierPath()
    for angle in stride(from: 100.0, through: 260.0, by: 40.0) {
        let rad = angle * .pi / 180
        burst.move(to: NSPoint(x: tip.x + cos(rad) * 70 * u, y: tip.y + sin(rad) * 70 * u))
        burst.line(to: NSPoint(x: tip.x + cos(rad) * 115 * u, y: tip.y + sin(rad) * 115 * u))
    }
    burst.lineWidth = 20 * u
    burst.lineCapStyle = .round
    NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.20, alpha: 1).setStroke()
    burst.stroke()

    // Pointer arrow, tip at `tip`, drawn on a 0..1 design then placed.
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, -0.78), (0.19, -0.60), (0.32, -0.90), (0.44, -0.85),
                                     (0.31, -0.55), (0.55, -0.55)]
    let h = 330 * u
    let arrow = NSBezierPath()
    for (i, p) in pts.enumerated() {
        let q = NSPoint(x: tip.x + p.0 * h, y: tip.y + p.1 * h)
        if i == 0 { arrow.move(to: q) } else { arrow.line(to: q) }
    }
    arrow.close()
    arrow.lineJoinStyle = .round
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 18 * u,
                  color: NSColor.black.withAlphaComponent(0.4).cgColor)
    NSColor.black.setStroke()
    arrow.lineWidth = 28 * u
    arrow.stroke()
    ctx.restoreGState()
    NSColor.white.setFill()
    arrow.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = drawIcon(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: iconset.appendingPathComponent(name))
    }
}
try! drawIcon(size: 1024).representation(using: .png, properties: [:])!
    .write(to: root.appendingPathComponent("Resources/AppIcon.png"))

let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
