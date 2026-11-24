import Domain
import RideEngine
import RoutesCore
import Testing
import TrainerKit
import VirtualTrainer

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RouteRideViewModelTests {
    let trainer = VirtualTrainer()
    let route: RouteIndex

    init() throws {
        // A camera at 5 m/s for 200 s: flat for 500 m, then a 6 % climb.
        route = try RouteIndex(
            points: (0...200).map { second in
                RouteIndex.Point(time: Double(second), distance: Double(second) * 5, grade: second < 100 ? 0 : 6)
            }
        )
    }

    func makeViewModel() async throws -> RouteRideViewModel {
        let client = FTMSTrainer(transport: trainer)
        try await client.connect()
        return RouteRideViewModel(name: "Test", route: route, connection: client, rider: RiderProfile())
    }

    @Test func startingPutsTheTrainerInSimulationOnTheFirstGradient() async throws {
        let ride = try await makeViewModel()
        await ride.start()
        #expect(ride.isRiding)
        #expect(await trainer.mode == .simulation(IndoorBikeSimulation(grade: 0)))
    }

    @Test func powerMovesTheRiderAndTheVideoFollows() async throws {
        let ride = try await makeViewModel()
        let listening = Task { await ride.listen() }
        defer { listening.cancel() }
        await ride.start()
        await trainer.advance(by: 5)
        while ride.power == 0 { await Task.yield() }

        var videoTime = 0.0
        for second in 0..<60 {
            await ride.step(seconds: 1, videoTime: videoTime, now: Double(second))
            if case .play(let rate) = ride.command { videoTime += rate }
        }
        #expect(ride.distance > 100)
        #expect(abs(route.videoTime(atDistance: ride.distance) - videoTime) < 1.5)
    }

    @Test func theClimbReachesTheTrainer() async throws {
        let ride = try await makeViewModel()
        await ride.start()
        // Ride to the climb at a steady 250 W.
        let listening = Task { await ride.listen() }
        defer { listening.cancel() }
        await trainer.setFreeRidePower(250)
        await trainer.advance(by: 10)
        var now = 0.0
        while ride.distance < 560 {
            await trainer.advance(by: 1)
            await ride.step(seconds: 1, videoTime: route.videoTime(atDistance: ride.distance), now: now)
            now += 1
        }
        #expect(ride.grade == Grade(percent: 6))
        #expect(await trainer.mode == .simulation(IndoorBikeSimulation(grade: 6)))
    }
}
