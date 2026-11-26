import Foundation

/// A GPS fix from a track recorded while filming.
public struct TrackPoint: Equatable, Sendable {
    /// Seconds on the recorder's clock.
    public var time: Double
    public var latitude: Double
    public var longitude: Double
    /// Metres above sea level.
    public var elevation: Double

    public init(time: Double, latitude: Double, longitude: Double, elevation: Double) {
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
}

/// Turns a GPS track into a ``RouteIndex``: one point per second of video,
/// with the distance along the route and a smoothed gradient.
public enum RouteBuilder {
    /// Mean Earth radius in metres.
    static let earthRadius = 6_371_000.0

    /// - Parameters:
    ///   - track: fixes in time order.
    ///   - videoStart: the track time that matches video time zero.
    ///   - videoDuration: video length in seconds.
    ///   - gradeWindow: metres over which the gradient is measured; GPS
    ///     elevation is noisy, so a short window gives wild gradients.
    public static func index(
        track: [TrackPoint],
        videoStart: Double,
        videoDuration: Double,
        gradeWindow: Double = 40
    ) throws(RouteIndexError) -> RouteIndex {
        guard track.count >= 2 else { throw .tooFewPoints(track.count) }
        var distances = [0.0]
        for (previous, next) in zip(track, track.dropFirst()) {
            distances.append(distances[distances.count - 1] + metres(from: previous, to: next))
        }
        let times = track.map(\.time)
        let elevations = track.map(\.elevation)

        func elevation(atDistance distance: Double) -> Double {
            interpolate(distance, xs: distances, ys: elevations)
        }

        let seconds = Int(videoDuration.rounded(.down))
        let points = (0...max(seconds, 1)).map { second -> RouteIndex.Point in
            let distance = interpolate(videoStart + Double(second), xs: times, ys: distances)
            let rise =
                elevation(atDistance: distance + gradeWindow / 2) - elevation(atDistance: distance - gradeWindow / 2)
            let grade = (rise / gradeWindow * 1000).rounded() / 10
            return RouteIndex.Point(time: Double(second), distance: (distance * 10).rounded() / 10, grade: grade)
        }
        return try RouteIndex(points: points)
    }

    /// Great-circle distance (haversine) between two fixes, in metres.
    public static func metres(from a: TrackPoint, to b: TrackPoint) -> Double {
        let radians = Double.pi / 180
        let dLatitude = (b.latitude - a.latitude) * radians
        let dLongitude = (b.longitude - a.longitude) * radians
        let h =
            sin(dLatitude / 2) * sin(dLatitude / 2)
            + cos(a.latitude * radians) * cos(b.latitude * radians) * sin(dLongitude / 2) * sin(dLongitude / 2)
        return 2 * earthRadius * asin(min(1, h.squareRoot()))
    }

    /// Linear interpolation of `ys` at `x`, clamped to the ends. `xs` must be
    /// non-decreasing.
    static func interpolate(_ x: Double, xs: [Double], ys: [Double]) -> Double {
        if x <= xs[0] { return ys[0] }
        if x >= xs[xs.count - 1] { return ys[ys.count - 1] }
        var low = 0
        var high = xs.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if xs[middle] <= x { low = middle } else { high = middle }
        }
        let span = xs[high] - xs[low]
        guard span > 0 else { return ys[high] }
        return ys[low] + (ys[high] - ys[low]) * (x - xs[low]) / span
    }
}
