import CoreGraphics

/// An 8-bit grayscale image, row-major, top row first.
public struct GrayImage: Equatable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixel count must equal width * height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    /// Renders `image` into a grayscale bitmap of the given size, resampling as needed.
    public init(_ image: CGImage, width: Int, height: Int) {
        let w = max(1, width), h = max(1, height)
        var px = [UInt8](repeating: 0, count: w * h)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        self.init(width: w, height: h, pixels: px)
    }
}

public struct Match: Equatable {
    /// Top-left of the best match, in pixels of the searched image.
    public let x: Int
    public let y: Int
    /// Mean absolute grayscale difference over the template, 0 (identical) to 255.
    public let score: Double
}

/// Finds where `template` best matches inside `image` by brute-force sum of absolute differences.
///
/// Locations whose running difference exceeds `cutoff` are abandoned early, which keeps this fast
/// for the usual case of a small button in a modest region. Returns nil if nothing scored under
/// `cutoff` or the template does not fit.
public func findTemplate(_ template: GrayImage, in image: GrayImage, cutoff: Double = 255) -> Match? {
    guard template.width <= image.width, template.height <= image.height,
          template.width > 0, template.height > 0 else { return nil }
    let n = template.width * template.height
    let limit = Int((cutoff * Double(n)).rounded(.up)) + 1
    var best = (x: 0, y: 0, sum: Int.max)
    template.pixels.withUnsafeBufferPointer { tp in
        image.pixels.withUnsafeBufferPointer { ip in
            for oy in 0...(image.height - template.height) {
                for ox in 0...(image.width - template.width) {
                    let cap = min(best.sum, limit)
                    var sum = 0
                    rows: for ty in 0..<template.height {
                        let ib = (oy + ty) * image.width + ox
                        let tb = ty * template.width
                        for tx in 0..<template.width {
                            sum += abs(Int(ip[ib + tx]) - Int(tp[tb + tx]))
                        }
                        if sum >= cap { break rows }
                    }
                    if sum < best.sum { best = (ox, oy, sum) }
                }
            }
        }
    }
    guard best.sum != Int.max else { return nil }
    let score = Double(best.sum) / Double(n)
    return score <= cutoff ? Match(x: best.x, y: best.y, score: score) : nil
}

/// Matches a saved button image against a capture of the watched region.
///
/// Both are compared at `workScale` pixels per screen point. Half a pixel per point is plenty to
/// recognize a button and is four times faster than full point resolution.
public struct ButtonFinder {
    public let region: CGRect
    public let template: GrayImage
    public let workScale: Double
    public var tolerance: Double

    public init(region: CGRect, buttonImage: CGImage, buttonSize: CGSize,
                tolerance: Double, workScale: Double = 0.5) {
        self.region = region
        self.workScale = workScale
        self.tolerance = tolerance
        template = GrayImage(buttonImage, width: Int(buttonSize.width * workScale),
                             height: Int(buttonSize.height * workScale))
    }

    /// Best match in a capture of `region`, regardless of tolerance.
    public func bestMatch(in capture: CGImage) -> Match? {
        let g = GrayImage(capture, width: Int(region.width * workScale), height: Int(region.height * workScale))
        return findTemplate(template, in: g)
    }

    /// Screen point at the center of the button, or nil if it is not visible within tolerance.
    public func locate(in capture: CGImage) -> CGPoint? {
        let g = GrayImage(capture, width: Int(region.width * workScale), height: Int(region.height * workScale))
        guard let m = findTemplate(template, in: g, cutoff: tolerance), m.score < tolerance else { return nil }
        return Geometry.screenPoint(ofMatch: m, templateWidth: template.width, templateHeight: template.height,
                                    region: region, workScale: workScale)
    }
}
