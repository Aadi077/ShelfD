import XCTest
@testable import ShelfDCore

final class ShakeDetectorTests: XCTestCase {
    /// Feeds a horizontal path at 120 Hz, returning whether any sample triggered a shake.
    private func run(_ detector: ShakeDetector, xs: [Double], y: Double = 500, hz: Double = 120) -> Bool {
        var fired = false
        for (i, x) in xs.enumerated() where detector.add(x: x, y: y, time: Double(i) / hz) {
            fired = true
        }
        return fired
    }

    /// A triangle wave between `from` and `to`, `stepsPerLeg` samples per leg.
    private func zigzag(from: Double, to: Double, legs: Int, stepsPerLeg: Int) -> [Double] {
        var xs: [Double] = []
        for leg in 0..<legs {
            let (a, b) = leg % 2 == 0 ? (from, to) : (to, from)
            for s in 0..<stepsPerLeg {
                xs.append(a + (b - a) * Double(s) / Double(stepsPerLeg))
            }
        }
        return xs
    }

    func testFastZigzagIsShake() {
        // 120 pt swings, ~83 ms per leg.
        XCTAssertTrue(run(ShakeDetector(), xs: zigzag(from: 400, to: 520, legs: 8, stepsPerLeg: 10)))
    }

    func testVerticalZigzagIsShake() {
        let detector = ShakeDetector()
        var fired = false
        for (i, y) in zigzag(from: 300, to: 420, legs: 8, stepsPerLeg: 10).enumerated()
        where detector.add(x: 500, y: y, time: Double(i) / 120) {
            fired = true
        }
        XCTAssertTrue(fired)
    }

    func testStraightDragIsNotShake() {
        XCTAssertFalse(run(ShakeDetector(), xs: (0..<240).map { Double($0) * 4 }))
    }

    func testSlowWobbleIsNotShake() {
        // Same swings, but 0.5 s per leg.
        XCTAssertFalse(run(ShakeDetector(), xs: zigzag(from: 400, to: 520, legs: 8, stepsPerLeg: 60)))
    }

    func testSmallJitterIsNotShake() {
        // Fast, but only 10 pt swings.
        XCTAssertFalse(run(ShakeDetector(), xs: zigzag(from: 400, to: 410, legs: 20, stepsPerLeg: 4)))
    }

    func testResetsAfterFiring() {
        let detector = ShakeDetector()
        XCTAssertTrue(run(detector, xs: zigzag(from: 400, to: 520, legs: 8, stepsPerLeg: 10)))
        // Right after firing, a single extra swing shouldn't fire again.
        XCTAssertFalse(detector.add(x: 400, y: 500, time: 10))
        XCTAssertFalse(detector.add(x: 520, y: 500, time: 10.05))
    }
}

final class ShakeSensitivityTests: XCTestCase {
    /// Feeds `legs` horizontal swings of `width` points, each lasting `legSeconds`.
    private func fires(_ sensitivity: ShakeSensitivity, width: Double, legs: Int, legSeconds: Double) -> Bool {
        let detector = ShakeDetector(config: sensitivity.config)
        let steps = 10
        var t = 0.0
        for leg in 0..<legs {
            let (a, b) = leg % 2 == 0 ? (0.0, width) : (width, 0.0)
            for s in 0..<steps {
                t += legSeconds / Double(steps)
                if detector.add(x: a + (b - a) * Double(s) / Double(steps), y: 0, time: t) { return true }
            }
        }
        return false
    }

    func testGentleCatchesSmallShakeThatNormalIgnores() {
        XCTAssertTrue(fires(.gentle, width: 28, legs: 6, legSeconds: 0.1))
        XCTAssertFalse(fires(.normal, width: 28, legs: 6, legSeconds: 0.1))
    }

    func testFirmIgnoresShortShakeThatNormalCatches() {
        XCTAssertTrue(fires(.normal, width: 120, legs: 5, legSeconds: 0.08))
        XCTAssertFalse(fires(.firm, width: 120, legs: 5, legSeconds: 0.08))
    }

    func testEveryPresetCatchesVigorousShake() {
        for sensitivity in ShakeSensitivity.allCases {
            XCTAssertTrue(fires(sensitivity, width: 150, legs: 10, legSeconds: 0.07), sensitivity.rawValue)
        }
    }
}
