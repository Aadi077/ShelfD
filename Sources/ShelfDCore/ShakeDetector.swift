import Foundation

/// Recognises a "shake" in a stream of cursor positions: several quick
/// back-and-forth direction changes along either axis.
public final class ShakeDetector {
    public struct Config {
        /// Minimum travel (points) back from the last extreme before a direction change counts.
        public var minSegment: Double
        /// Direction changes needed within `window` to count as a shake.
        public var requiredReversals: Int
        /// Time window (seconds) the reversals must fall in.
        public var window: TimeInterval

        public init(minSegment: Double = 30, requiredReversals: Int = 4, window: TimeInterval = 0.7) {
            self.minSegment = minSegment
            self.requiredReversals = requiredReversals
            self.window = window
        }
    }

    public var config: Config
    private var xAxis = AxisTracker()
    private var yAxis = AxisTracker()

    public init(config: Config = Config()) {
        self.config = config
    }

    public func reset() {
        xAxis = AxisTracker()
        yAxis = AxisTracker()
    }

    /// Feeds one cursor sample. Returns true when this sample completes a shake;
    /// the detector then resets itself.
    @discardableResult
    public func add(x: Double, y: Double, time: TimeInterval) -> Bool {
        let shookX = xAxis.add(x, time: time, config: config)
        let shookY = yAxis.add(y, time: time, config: config)
        if shookX || shookY {
            reset()
            return true
        }
        return false
    }
}

private struct AxisTracker {
    private var anchor: Double?
    private var extreme: Double = 0
    private var direction: Double = 0
    private var reversals: [TimeInterval] = []

    mutating func add(_ value: Double, time: TimeInterval, config: ShakeDetector.Config) -> Bool {
        guard let start = anchor else {
            anchor = value
            return false
        }

        if direction == 0 {
            // Wait for the first decisive movement to establish a direction.
            if abs(value - start) >= config.minSegment {
                direction = value > start ? 1 : -1
                extreme = value
            }
            return false
        }

        if (value - extreme) * direction > 0 {
            extreme = value
        } else if (extreme - value) * direction >= config.minSegment {
            direction = -direction
            extreme = value
            reversals.append(time)
        }

        reversals.removeAll { time - $0 > config.window }
        return reversals.count >= config.requiredReversals
    }
}
