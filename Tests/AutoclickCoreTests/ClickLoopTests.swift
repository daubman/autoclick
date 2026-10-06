import CoreGraphics
import XCTest
@testable import AutoclickCore

/// Simulates a screen where the target is visible during scripted time windows.
final class FakeScreen: ClickEnvironment {
    var now = 0.0
    var visible: (Double) -> Bool
    var target = CGPoint(x: 10, y: 20)
    var clicks: [Double] = []
    var logs: [String] = []
    var stopAt = Double.infinity
    /// Called on each click so a test can make the target react.
    var onClick: (FakeScreen) -> Void = { _ in }

    init(visible: @escaping (Double) -> Bool) { self.visible = visible }

    func locate() -> CGPoint? { visible(now) ? target : nil }
    func click(at point: CGPoint) {
        XCTAssertEqual(point, target)
        clicks.append(now)
        onClick(self)
    }
    func sleep(_ seconds: Double) { now += seconds }
    func shouldStop() -> Bool { now >= stopAt }
    func log(_ message: String) { logs.append(message) }
    func didClick(count: Int) {}
}

final class ClickLoopTests: XCTestCase {
    var settings: ClickLoopSettings {
        var s = ClickLoopSettings()
        s.interval = 0.5
        s.settleDelay = 0.4
        s.retryAfter = 15
        return s
    }

    /// The target reappears for each queue item and disappears for a while after each click.
    func testClicksEachTimeTheTargetReappears() {
        var hiddenUntil = 0.0
        let screen = FakeScreen(visible: { _ in true })
        screen.visible = { t in t >= hiddenUntil }
        screen.onClick = { s in hiddenUntil = s.now + 8 }
        var s = settings
        s.maxClicks = 5
        XCTAssertEqual(runClickLoop(s, screen), .finished(clicks: 5))
        XCTAssertEqual(screen.clicks.count, 5)
        // Every click comes after the target came back.
        for pair in zip(screen.clicks, screen.clicks.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 8) }
    }

    func testWaitsForTheTargetToAppear() {
        let screen = FakeScreen(visible: { t in t >= 3 })
        var s = settings
        s.maxClicks = 1
        XCTAssertEqual(runClickLoop(s, screen), .finished(clicks: 1))
        XCTAssertGreaterThanOrEqual(screen.clicks[0], 3 + s.settleDelay)
    }

    func testClicksAgainWhenTheTargetNeverGoesAway() {
        let screen = FakeScreen(visible: { _ in true })
        var s = settings
        s.maxClicks = 3
        XCTAssertEqual(runClickLoop(s, screen), .finished(clicks: 3))
        XCTAssertEqual(screen.clicks[1] - screen.clicks[0], s.retryAfter + s.settleDelay, accuracy: 0.001)
        XCTAssertTrue(screen.logs.contains { $0.contains("clicking again") })
    }

    func testDoesNotClickIfTheTargetVanishesWhileSettling() {
        // Visible only for a flicker shorter than the settle delay, then for good from t=5.
        let screen = FakeScreen(visible: { t in (t >= 1 && t < 1.2) || t >= 5 })
        var s = settings
        s.interval = 0.1
        s.maxClicks = 1
        XCTAssertEqual(runClickLoop(s, screen), .finished(clicks: 1))
        XCTAssertGreaterThanOrEqual(screen.clicks[0], 5)
    }

    func testStopsWhileWaiting() {
        let screen = FakeScreen(visible: { _ in false })
        screen.stopAt = 10
        XCTAssertEqual(runClickLoop(settings, screen), .stopped(clicks: 0))
        XCTAssertTrue(screen.clicks.isEmpty)
    }

    func testStopsAfterAClick() {
        var hiddenUntil = 0.0
        let screen = FakeScreen(visible: { _ in true })
        screen.visible = { t in t >= hiddenUntil }
        screen.onClick = { s in hiddenUntil = s.now + 8 }
        screen.stopAt = 12
        XCTAssertEqual(runClickLoop(settings, screen), .stopped(clicks: 2))
    }

    func testLogsWhileWaitingForALongTime() {
        let screen = FakeScreen(visible: { _ in false })
        screen.stopAt = 95
        _ = runClickLoop(settings, screen)
        XCTAssertEqual(screen.logs.filter { $0.contains("Still waiting") }.count, 3)
    }
}
