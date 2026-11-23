/// Keeps a route video in step with a rider on a trainer.
///
/// The rider's virtual distance decides which frame should be on screen; the
/// video player only knows its own clock. Each tick this compares the two and
/// tells the player what to do:
///
/// - the base playback rate is the rider's speed over the camera's speed at
///   that point of the route, so 30 km/h over footage filmed at 20 km/h
///   plays at 1.5x;
/// - a small correction toward the right frame stops drift from building up:
///   `rate = base + drift / correctionTime`;
/// - a large drift (after a pause, or a sprint beyond the maximum rate)
///   seeks instead of racing;
/// - below a walking pace the video pauses.
///
/// Pure and stateless, so every rule is tested without a video player.
public struct VideoSync: Equatable, Sendable {
    public let route: RouteIndex
    public var configuration: Configuration

    public init(route: RouteIndex, configuration: Configuration = Configuration()) {
        self.route = route
        self.configuration = configuration
    }

    public struct Configuration: Equatable, Sendable {
        /// Slowest and fastest playback rate the player is asked for.
        public var minimumRate: Double
        public var maximumRate: Double
        /// Seconds over which a drift is corrected.
        public var correctionTime: Double
        /// A drift of more than this many seconds is fixed with a seek.
        public var seekThreshold: Double
        /// Below this rider speed (m/s) the video pauses.
        public var pauseBelowSpeed: Double

        public init(
            minimumRate: Double = 0.1,
            maximumRate: Double = 2,
            correctionTime: Double = 2,
            seekThreshold: Double = 5,
            pauseBelowSpeed: Double = 0.5
        ) {
            self.minimumRate = minimumRate
            self.maximumRate = maximumRate
            self.correctionTime = correctionTime
            self.seekThreshold = seekThreshold
            self.pauseBelowSpeed = pauseBelowSpeed
        }
    }

    public enum Command: Equatable, Sendable {
        case play(rate: Double)
        case seek(to: Double, rate: Double)
        case pause
        /// The rider passed the end of the route.
        case finished
    }

    /// What the player should do now.
    ///
    /// - Parameters:
    ///   - riderDistance: metres ridden along the route.
    ///   - riderSpeed: the rider's virtual speed in m/s.
    ///   - videoTime: the player's current time in seconds.
    public func command(riderDistance: Double, riderSpeed: Double, videoTime: Double) -> Command {
        if riderDistance >= route.totalDistance { return .finished }
        if riderSpeed < configuration.pauseBelowSpeed { return .pause }

        let targetTime = route.videoTime(atDistance: riderDistance)
        let recordedSpeed = route.recordedSpeed(atDistance: riderDistance)
        // Where the camera barely moved, pass through as fast as allowed.
        let baseRate = recordedSpeed > 0.1 ? riderSpeed / recordedSpeed : configuration.maximumRate

        let drift = targetTime - videoTime
        if abs(drift) > configuration.seekThreshold {
            return .seek(to: targetTime, rate: clamped(baseRate))
        }
        return .play(rate: clamped(baseRate + drift / configuration.correctionTime))
    }

    /// The gradient to send to the trainer for the rider's position.
    public func grade(atDistance distance: Double) -> Grade {
        route.grade(atDistance: distance)
    }

    private func clamped(_ rate: Double) -> Double {
        min(max(rate, configuration.minimumRate), configuration.maximumRate)
    }
}
