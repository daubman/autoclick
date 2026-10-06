import CoreGraphics
import XCTest
@testable import AutoclickCore

/// Deterministic noisy background so a template only matches where it was placed.
func noise(width: Int, height: Int, seed: UInt64 = 42) -> GrayImage {
    var state = seed
    let px = (0..<(width * height)).map { _ -> UInt8 in
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8(truncatingIfNeeded: state >> 56)
    }
    return GrayImage(width: width, height: height, pixels: px)
}

func crop(_ img: GrayImage, x: Int, y: Int, width: Int, height: Int) -> GrayImage {
    var px: [UInt8] = []
    for row in y..<(y + height) { px += img.pixels[(row * img.width + x)..<(row * img.width + x + width)] }
    return GrayImage(width: width, height: height, pixels: px)
}

func cgImage(_ g: GrayImage) -> CGImage {
    let data = CFDataCreate(nil, g.pixels, g.pixels.count)!
    return CGImage(width: g.width, height: g.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: g.width,
                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                   provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: false,
                   intent: .defaultIntent)!
}

final class MatcherTests: XCTestCase {
    func testFindsExactCopy() {
        let img = noise(width: 120, height: 80)
        let t = crop(img, x: 37, y: 21, width: 20, height: 10)
        XCTAssertEqual(findTemplate(t, in: img), Match(x: 37, y: 21, score: 0))
    }

    func testFindsAtEdges() {
        let img = noise(width: 60, height: 40)
        XCTAssertEqual(findTemplate(crop(img, x: 0, y: 0, width: 8, height: 8), in: img)?.x, 0)
        let corner = findTemplate(crop(img, x: 52, y: 32, width: 8, height: 8), in: img)
        XCTAssertEqual(corner?.x, 52)
        XCTAssertEqual(corner?.y, 32)
    }

    func testToleratesSmallDifferences() {
        let img = noise(width: 100, height: 60)
        var t = crop(img, x: 50, y: 30, width: 16, height: 8)
        t.pixels = t.pixels.map { $0 > 250 ? $0 - 5 : $0 + 5 } // e.g. hover tint or antialiasing
        let m = findTemplate(t, in: img, cutoff: 18)
        XCTAssertEqual(m?.x, 50)
        XCTAssertEqual(m?.y, 30)
        XCTAssertEqual(m?.score ?? 99, 5, accuracy: 0.01)
    }

    func testRejectsAbsentTemplate() {
        let img = noise(width: 100, height: 60, seed: 1)
        let unrelated = crop(noise(width: 100, height: 60, seed: 2), x: 10, y: 10, width: 16, height: 8)
        XCTAssertNil(findTemplate(unrelated, in: img, cutoff: 18))
        // Without a cutoff the best location is still reported, with a poor score.
        XCTAssertGreaterThan(findTemplate(unrelated, in: img)?.score ?? 0, 18)
    }

    func testTemplateLargerThanImage() {
        XCTAssertNil(findTemplate(noise(width: 10, height: 10), in: noise(width: 5, height: 5)))
    }

    func testTemplateSameSizeAsImage() {
        let img = noise(width: 12, height: 7)
        XCTAssertEqual(findTemplate(img, in: img), Match(x: 0, y: 0, score: 0))
    }

    func testGrayImageFromCGImageRoundTrips() {
        let g = noise(width: 30, height: 20)
        XCTAssertEqual(GrayImage(cgImage(g), width: 30, height: 20), g)
    }

    func testGrayImageFromCGImageKeepsTopRowFirst() {
        var g = GrayImage(width: 4, height: 4, pixels: .init(repeating: 0, count: 16))
        for x in 0..<4 { g[x, 0] = 255 }
        let back = GrayImage(cgImage(g), width: 4, height: 4)
        XCTAssertEqual(back[0, 0], 255)
        XCTAssertEqual(back[0, 3], 0)
    }

    /// End to end at a Retina-like 2x capture: the region is 100x60 points, captured at 200x120
    /// pixels, and the target sits at (40, 20) points with a 20x10 point size.
    func testButtonFinderLocatesCenterInScreenPoints() {
        let screen = noise(width: 200, height: 120, seed: 7)
        let button = crop(screen, x: 80, y: 40, width: 40, height: 20)
        let finder = ButtonFinder(region: CGRect(x: 1000, y: 500, width: 100, height: 60),
                                  buttonImage: cgImage(button), buttonSize: CGSize(width: 20, height: 10),
                                  tolerance: 18, workScale: 1)
        let p = finder.locate(in: cgImage(screen))
        XCTAssertEqual(p, CGPoint(x: 1050, y: 525))
    }

    func testButtonFinderReturnsNilWhenAbsent() {
        let button = crop(noise(width: 200, height: 120, seed: 7), x: 80, y: 40, width: 40, height: 20)
        let finder = ButtonFinder(region: CGRect(x: 0, y: 0, width: 100, height: 60),
                                  buttonImage: cgImage(button), buttonSize: CGSize(width: 20, height: 10),
                                  tolerance: 18, workScale: 1)
        XCTAssertNil(finder.locate(in: cgImage(noise(width: 200, height: 120, seed: 8))))
    }
}
