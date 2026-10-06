import CoreGraphics

/// Coordinate conversions. Three spaces are involved:
/// - Global screen points with a top-left origin, used by mouse events and `screencapture -R`.
/// - Cocoa screen points with a bottom-left origin, used by windows and views.
/// - Image pixels with a top-left origin, which differ from points by the display scale.
public enum Geometry {
    /// Converts a Cocoa (bottom-left origin) rect to global top-left coordinates.
    public static func flipped(_ r: CGRect, primaryScreenHeight h: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

    /// Normalized rect between two corner points.
    public static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Where an image of `imageSize` lands when fit, centered, inside `bounds` without distortion.
    public static func aspectFit(_ imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let s = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * s, height: imageSize.height * s)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// Converts a selection drawn in a bottom-left-origin view over an image displayed at
    /// `imageRect` into a top-left-origin crop rect in the image's own pixels.
    public static func cropRect(selection: CGRect, imageRect: CGRect, imagePixelSize: CGSize) -> CGRect {
        let sx = imagePixelSize.width / imageRect.width
        let sy = imagePixelSize.height / imageRect.height
        let r = CGRect(x: (selection.minX - imageRect.minX) * sx,
                       y: (imageRect.maxY - selection.maxY) * sy,
                       width: selection.width * sx,
                       height: selection.height * sy).integral
        return r.intersection(CGRect(origin: .zero, size: imagePixelSize))
    }

    /// Screen point at the center of a template match found in a region capture.
    public static func screenPoint(ofMatch m: Match, templateWidth: Int, templateHeight: Int,
                                   region: CGRect, workScale: Double) -> CGPoint {
        CGPoint(x: region.minX + (Double(m.x) + Double(templateWidth) / 2) / workScale,
                y: region.minY + (Double(m.y) + Double(templateHeight) / 2) / workScale)
    }
}
