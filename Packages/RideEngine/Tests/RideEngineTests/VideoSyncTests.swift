import Foundation
import RideEngine
import Testing

/// A camera that moved at a steady 5 m/s for 100 s on a 2 % climb.
func steadyRoute(speed: Double = 5, seconds: Int = 100) throws -> RouteIndex {
    try RouteIndex(
        points: (0...seconds).map { RouteIndex.Point(time: Double($0), distance: Double($0) * speed, grade: 2) }
    )
}

struct RouteIndexTests {
    @Test func interpolatesVideoTimeBetweenPoints() throws {
        let route = try steadyRoute()
        #expect(route.videoTime(atDistance: 252.5) == 50.5)
        #expect(route.totalDistance == 500)
        #expect(route.duration == 100)
    }

    @Test func recordedSpeedIsDistanceOverTime() throws {
        #expect(try steadyRoute().recordedSpeed(atDistance: 123) == 5)
    }

    @Test func skipsWhereTheCameraStoodStill() throws {
        // Stopped at a traffic light between seconds 2 and 5.
        let route = try RouteIndex(points: [
            .init(time: 0, distance: 0, grade: 0),
            .init(time: 1, distance: 5, grade: 0),
            .init(time: 2, distance: 10, grade: 0),
            .init(time: 5, distance: 10, grade: 0),
            .init(time: 6, distance: 15, grade: 0),
        ])
        #expect(route.videoTime(atDistance: 10) == 5)
        #expect(route.videoTime(atDistance: 12.5) == 5.5)
        #expect(route.recordedSpeed(atDistance: 12.5) == 5)
    }

    @Test func interpolatesGrade() throws {
        let route = try RouteIndex(points: [
            .init(time: 0, distance: 0, grade: 0),
            .init(time: 10, distance: 100, grade: 4),
        ])
        #expect(route.grade(atDistance: 25) == Grade(percent: 1))
        #expect(route.grade(atDistance: 500) == Grade(percent: 4))
        #expect(route.grade(atDistance: -10) == Grade(percent: 0))
    }

    @Test(arguments: [
        ([RouteIndex.Point(time: 0, distance: 0, grade: 0)], RouteIndexError.tooFewPoints(1)),
        ([.init(time: 0, distance: 0, grade: 0), .init(time: 0, distance: 5, grade: 0)], .timeNotIncreasing(at: 0)),
        ([.init(time: 0, distance: 5, grade: 0), .init(time: 1, distance: 4, grade: 0)], .distanceDecreasing(at: 1)),
    ])
    func rejectsBrokenIndexes(points: [RouteIndex.Point], error: RouteIndexError) {
        #expect(throws: error) {
            try RouteIndex(points: points)
        }
    }

    @Test func decodesFromTheVideoPipelineJSON() throws {
        let json = Data(#"[{"time":0,"distance":0,"grade":1.5},{"time":1,"distance":6.2,"grade":1.7}]"#.utf8)
        let route = try JSONDecoder().decode(RouteIndex.self, from: json)
        #expect(route.points.count == 2)
        #expect(route.points[1].distance == 6.2)
    }

    @Test func decodingRejectsABrokenIndex() {
        let json = Data(#"[{"time":0,"distance":0,"grade":0}]"#.utf8)
        #expect(throws: RouteIndexError.tooFewPoints(1)) {
            try JSONDecoder().decode(RouteIndex.self, from: json)
        }
    }
}

struct VideoSyncTests {
    @Test(arguments: [(5.0, 1.0), (10.0, 2.0), (2.5, 0.5), (20.0, 2.0), (0.6, 0.12)])
    func rateIsRiderSpeedOverCameraSpeed(riderSpeed: Double, rate: Double) throws {
        let sync = VideoSync(route: try steadyRoute())
        let command = sync.command(riderDistance: 250, riderSpeed: riderSpeed, videoTime: 50)
        guard case .play(let actual) = command else {
            Issue.record("expected play, got \(command)")
            return
        }
        #expect(abs(actual - rate) < 1e-9)
    }

    @Test func pausesBelowWalkingPace() throws {
        let sync = VideoSync(route: try steadyRoute())
        #expect(sync.command(riderDistance: 250, riderSpeed: 0.2, videoTime: 50) == .pause)
    }

    @Test func speedsUpToCatchUpASmallDrift() throws {
        let sync = VideoSync(route: try steadyRoute())
        // The video is one second behind: 1 + 1 / 2 s correction time.
        #expect(sync.command(riderDistance: 250, riderSpeed: 5, videoTime: 49) == .play(rate: 1.5))
    }

    @Test func seeksWhenTheDriftIsLarge() throws {
        let sync = VideoSync(route: try steadyRoute())
        #expect(sync.command(riderDistance: 250, riderSpeed: 5, videoTime: 40) == .seek(to: 50, rate: 1))
    }

    @Test func finishesAtTheEndOfTheRoute() throws {
        let sync = VideoSync(route: try steadyRoute())
        #expect(sync.command(riderDistance: 500, riderSpeed: 5, videoTime: 99) == .finished)
    }

    @Test func driftConvergesWhenThePlayerFollowsTheCommands() throws {
        let sync = VideoSync(route: try steadyRoute())
        var riderDistance = 100.0
        var videoTime = 17.0  // 3 s behind the rider's position
        let tick = 0.1
        var drift = 0.0
        for _ in 0..<300 {
            riderDistance += 4 * tick
            // Drift as the controller sees it: before the player moves this tick.
            drift = sync.route.videoTime(atDistance: riderDistance) - videoTime
            switch sync.command(riderDistance: riderDistance, riderSpeed: 4, videoTime: videoTime) {
            case .play(let rate): videoTime += rate * tick
            case .seek(let time, let rate): videoTime = time + rate * tick
            case .pause, .finished: break
            }
        }
        #expect(abs(drift) < 0.001)
    }
}
