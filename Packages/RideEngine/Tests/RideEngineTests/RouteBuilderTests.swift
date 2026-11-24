import RideEngine
import Testing

struct RouteBuilderTests {
    /// Riding due north: 0.0005 degrees of latitude (about 55.6 m) every 10 s,
    /// climbing 2.78 m each time, which is a 5 % gradient.
    let track = (0...20).map { step in
        TrackPoint(
            time: 1000 + Double(step) * 10,
            latitude: 52.37 + Double(step) * 0.0005,
            longitude: 5.21,
            elevation: Double(step) * 2.78
        )
    }

    @Test func haversineMatchesTheLengthOfALatitudeDegree() {
        let a = TrackPoint(time: 0, latitude: 52, longitude: 5, elevation: 0)
        let b = TrackPoint(time: 0, latitude: 53, longitude: 5, elevation: 0)
        // One degree of latitude on a 6371 km sphere: 111.195 km.
        #expect(abs(RouteBuilder.metres(from: a, to: b) - 111_195) < 1)
    }

    @Test func onePointPerVideoSecondAlignedToTheVideoStart() throws {
        let route = try RouteBuilder.index(track: track, videoStart: 1050, videoDuration: 100)
        #expect(route.points.count == 101)
        #expect(route.points[0].time == 0)
        // 50 s into the track: 5 steps of 55.6 m.
        #expect(abs(route.points[0].distance - 278) < 1)
        #expect(abs(route.recordedSpeed(atDistance: 400) - 5.56) < 0.05)
    }

    @Test func gradeIsSmoothedFromElevation() throws {
        let route = try RouteBuilder.index(track: track, videoStart: 1000, videoDuration: 150)
        #expect(abs(route.points[60].grade - 5) < 0.2)
    }

    @Test func aTrackOfOnePointIsRejected() {
        #expect(throws: RouteIndexError.tooFewPoints(1)) {
            try RouteBuilder.index(track: [track[0]], videoStart: 0, videoDuration: 10)
        }
    }
}
