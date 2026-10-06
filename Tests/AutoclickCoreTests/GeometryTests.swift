import CoreGraphics
import XCTest
@testable import AutoclickCore

final class GeometryTests: XCTestCase {
    func testFlippedConvertsBottomLeftToTopLeft() {
        let r = Geometry.flipped(CGRect(x: 10, y: 100, width: 50, height: 20), primaryScreenHeight: 1000)
        XCTAssertEqual(r, CGRect(x: 10, y: 880, width: 50, height: 20))
    }

    func testFlippedHandlesDisplaysAboveThePrimary() {
        // A display above the primary has Cocoa y beyond the primary's height: negative top-left y.
        let r = Geometry.flipped(CGRect(x: 0, y: 1100, width: 100, height: 50), primaryScreenHeight: 1000)
        XCTAssertEqual(r.minY, -150)
    }

    func testRectNormalizesCorners() {
        XCTAssertEqual(Geometry.rect(CGPoint(x: 50, y: 10), CGPoint(x: 20, y: 40)),
                       CGRect(x: 20, y: 10, width: 30, height: 30))
    }

    func testAspectFitCentersWideImage() {
        let r = Geometry.aspectFit(CGSize(width: 200, height: 50), in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(r, CGRect(x: 0, y: 37.5, width: 100, height: 25))
    }

    func testCropRectAtRetinaScale() {
        // Image is 400x200 pixels, shown at 200x100 points starting at (10, 20) in the view.
        // A selection at view (60, 70) size 40x20 is 50 points right of the image's left edge,
        // and its top (90) is 30 points below the image's top (120).
        let crop = Geometry.cropRect(selection: CGRect(x: 60, y: 70, width: 40, height: 20),
                                     imageRect: CGRect(x: 10, y: 20, width: 200, height: 100),
                                     imagePixelSize: CGSize(width: 400, height: 200))
        XCTAssertEqual(crop, CGRect(x: 100, y: 60, width: 80, height: 40))
    }

    func testCropRectIsClampedToTheImage() {
        let crop = Geometry.cropRect(selection: CGRect(x: -5, y: -5, width: 30, height: 30),
                                     imageRect: CGRect(x: 0, y: 0, width: 20, height: 20),
                                     imagePixelSize: CGSize(width: 20, height: 20))
        XCTAssertEqual(crop, CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    func testScreenPointOfMatch() {
        let p = Geometry.screenPoint(ofMatch: Match(x: 10, y: 4, score: 0), templateWidth: 20, templateHeight: 6,
                                     region: CGRect(x: 100, y: 200, width: 300, height: 100), workScale: 0.5)
        // Center in work pixels is (20, 7); at half a pixel per point that is (40, 14) points.
        XCTAssertEqual(p, CGPoint(x: 140, y: 214))
    }
}
