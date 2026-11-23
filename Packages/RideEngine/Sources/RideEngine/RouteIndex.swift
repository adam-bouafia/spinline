/// Where a recorded route video is, in space, at each moment.
///
/// The video pipeline (FFmpeg plus the GPX track recorded during filming)
/// writes one point per video second: the distance along the route and the
/// smoothed gradient. With it the app can answer "which frame shows the place
/// the rider has reached?" and "how fast was the camera moving there?".
public struct RouteIndex: Equatable, Sendable, Codable {
    public struct Point: Equatable, Sendable, Codable {
        /// Seconds from the start of the video.
        public var time: Double
        /// Metres along the route.
        public var distance: Double
        /// Gradient in percent at this point.
        public var grade: Double

        public init(time: Double, distance: Double, grade: Double) {
            self.time = time
            self.distance = distance
            self.grade = grade
        }
    }

    public let points: [Point]

    /// - Throws: ``RouteIndexError`` when there are fewer than two points, or
    ///   time or distance go backwards.
    public init(points: [Point]) throws(RouteIndexError) {
        guard points.count >= 2 else { throw .tooFewPoints(points.count) }
        for (previous, next) in zip(points, points.dropFirst()) {
            guard next.time > previous.time else { throw .timeNotIncreasing(at: next.time) }
            guard next.distance >= previous.distance else { throw .distanceDecreasing(at: next.time) }
        }
        self.points = points
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(points: container.decode([Point].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(points)
    }

    public var totalDistance: Double { points[points.count - 1].distance }
    public var duration: Double { points[points.count - 1].time }

    /// The video time at which the camera reached `distance`, interpolated
    /// between points. Where the camera stood still, the moment it moved on,
    /// so stops in the recording are skipped.
    public func videoTime(atDistance distance: Double) -> Double {
        let distance = clamped(distance)
        let (before, after) = bracket(distance)
        let span = after.distance - before.distance
        guard span > 0 else { return before.time }
        return before.time + (after.time - before.time) * (distance - before.distance) / span
    }

    /// The camera's speed in m/s around `distance`.
    public func recordedSpeed(atDistance distance: Double) -> Double {
        let (before, after) = bracket(distance)
        return (after.distance - before.distance) / (after.time - before.time)
    }

    /// The gradient at `distance`, interpolated; before the start and after
    /// the end, the gradient there.
    public func grade(atDistance distance: Double) -> Grade {
        let distance = clamped(distance)
        let (before, after) = bracket(distance)
        let span = after.distance - before.distance
        guard span > 0 else { return Grade(percent: before.grade) }
        let fraction = (distance - before.distance) / span
        return Grade(percent: before.grade + (after.grade - before.grade) * fraction)
    }

    private func clamped(_ distance: Double) -> Double {
        min(max(distance, points[0].distance), totalDistance)
    }

    /// The two neighbouring points around `distance` (clamped to the route),
    /// found by binary search: a 30-minute video has 1800 points and this
    /// runs on every frame.
    private func bracket(_ distance: Double) -> (Point, Point) {
        if distance <= points[0].distance { return (points[0], points[1]) }
        if distance >= totalDistance {
            // Past the end, or on a final stretch where the camera stood still:
            // use the last segment that moved.
            let last = points.count - 1
            let moving = (1...last).last { points[$0].distance > points[$0 - 1].distance } ?? last
            return (points[moving - 1], points[moving])
        }
        // First point strictly beyond `distance`.
        var low = 0
        var high = points.count - 1
        while low < high {
            let middle = (low + high) / 2
            if points[middle].distance <= distance { low = middle + 1 } else { high = middle }
        }
        return (points[low - 1], points[low])
    }
}

public enum RouteIndexError: Error, Equatable, Sendable {
    case tooFewPoints(Int)
    case timeNotIncreasing(at: Double)
    case distanceDecreasing(at: Double)
}
