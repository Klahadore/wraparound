import XCTest
import CoreGraphics
@testable import WrapCore

final class WrapTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 932)

    func testRightEdgePushingRightWrapsToLeft() {
        let p = Wrap.target(location: CGPoint(x: 1439, y: 400), deltaX: 5, bounds: screen)
        XCTAssertEqual(p, CGPoint(x: 5, y: 400))
    }

    func testLeftEdgePushingLeftWrapsToRight() {
        let p = Wrap.target(location: CGPoint(x: 0, y: 300), deltaX: -3, bounds: screen)
        XCTAssertEqual(p, CGPoint(x: 1436, y: 300))
    }

    func testFractionalEdgePositionStillWraps() {
        XCTAssertNotNil(Wrap.target(location: CGPoint(x: 1439.6, y: 10), deltaX: 0.4, bounds: screen))
    }

    func testAtEdgeMovingInwardDoesNotWrap() {
        XCTAssertNil(Wrap.target(location: CGPoint(x: 1439, y: 400), deltaX: -5, bounds: screen))
        XCTAssertNil(Wrap.target(location: CGPoint(x: 0, y: 400), deltaX: 5, bounds: screen))
    }

    func testVerticalOnlyMovementAtEdgeDoesNotWrap() {
        XCTAssertNil(Wrap.target(location: CGPoint(x: 1439, y: 400), deltaX: 0, bounds: screen))
        XCTAssertNil(Wrap.target(location: CGPoint(x: 0, y: 400), deltaX: 0, bounds: screen))
    }

    func testNotAtEdgeDoesNotWrap() {
        XCTAssertNil(Wrap.target(location: CGPoint(x: 1000, y: 400), deltaX: 50, bounds: screen))
        XCTAssertNil(Wrap.target(location: CGPoint(x: 1, y: 400), deltaX: -50, bounds: screen))
    }

    func testTopAndBottomNeverWrap() {
        XCTAssertNil(Wrap.target(location: CGPoint(x: 700, y: 0), deltaX: 0, bounds: screen))
        XCTAssertNil(Wrap.target(location: CGPoint(x: 700, y: 931), deltaX: 0, bounds: screen))
    }

    func testFastFlickCarryIsCapped() {
        let p = Wrap.target(location: CGPoint(x: 1439, y: 0), deltaX: 400, bounds: screen)
        XCTAssertEqual(p?.x, Wrap.maxCarry)
    }

    func testLandingSpotIsNotItselfAnEdge() {
        // After wrapping right->left we land at x>=1, so continuing right never re-wraps.
        let p = Wrap.target(location: CGPoint(x: 1439, y: 0), deltaX: 0.1, bounds: screen)!
        XCTAssertNil(Wrap.target(location: p, deltaX: 0.1, bounds: screen))
        XCTAssertNil(Wrap.target(location: p, deltaX: -0.1, bounds: screen))
    }

    func testYIsClampedIntoDesktop() {
        let p = Wrap.target(location: CGPoint(x: 1439, y: 5000), deltaX: 2, bounds: screen)
        XCTAssertEqual(p?.y, 931)
    }

    func testOffsetDesktopBounds() {
        let b = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        XCTAssertEqual(Wrap.target(location: CGPoint(x: -1, y: 10), deltaX: 2, bounds: b), CGPoint(x: -1438, y: 10))
        XCTAssertEqual(Wrap.target(location: CGPoint(x: -1440, y: 10), deltaX: -2, bounds: b), CGPoint(x: -3, y: 10))
    }

    func testDesktopBoundsUnion() {
        let u = Wrap.desktopBounds([CGRect(x: 0, y: 0, width: 100, height: 50), CGRect(x: 100, y: 0, width: 80, height: 60)])
        XCTAssertEqual(u, CGRect(x: 0, y: 0, width: 180, height: 60))
        XCTAssertTrue(Wrap.desktopBounds([]).isNull)
        XCTAssertNil(Wrap.target(location: .zero, deltaX: -1, bounds: .null))
    }
}
