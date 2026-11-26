import Domain
import Observation
import RideEngine

/// Riding a filmed route.
///
/// Every step: the rider's power (from the trainer) moves a ``RideSimulator``
/// along the route's gradient; ``VideoSync`` turns the resulting distance and
/// speed into a player command; the gradient goes to the trainer in
/// simulation mode, so a climb in the video feels like one.
@MainActor
@Observable
public final class RouteRideViewModel {
    public let name: String
    public let route: RouteIndex
    public private(set) var power = 0
    /// Metres along the route.
    public private(set) var distance = 0.0
    /// Virtual speed in m/s.
    public private(set) var speed = 0.0
    public private(set) var grade = Grade.flat
    public private(set) var command = VideoSync.Command.pause
    public private(set) var isRiding = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let connection: any TrainerConnection
    @ObservationIgnored private let sync: VideoSync
    @ObservationIgnored private var simulator: RideSimulator
    @ObservationIgnored private var sentGrade: Double?
    @ObservationIgnored private var sentAt = -Double.infinity

    public init(name: String, route: RouteIndex, connection: any TrainerConnection, rider: RiderProfile) {
        self.name = name
        self.route = route
        self.connection = connection
        sync = VideoSync(route: route)
        simulator = RideSimulator(physics: CyclingPhysics(rider: rider))
    }

    public var progress: Double { route.totalDistance > 0 ? min(distance / route.totalDistance, 1) : 0 }

    public func start() async {
        do {
            try await connection.send(.start)
        } catch TrainerError.operationFailed {
            // Already started (for example by a workout): carry on.
        } catch {
            errorMessage = "The trainer did not start: \(error)"
            return
        }
        isRiding = true
        await sendGrade(now: 0, force: true)
    }

    /// Advances the ride by `seconds` while the player shows `videoTime`.
    /// - Parameter now: seconds on a monotonic clock, to pace trainer commands.
    public func step(seconds: Double, videoTime: Double, now: Double) async {
        guard isRiding else { return }
        simulator.advance(power: Double(power), grade: grade, duration: seconds)
        distance = simulator.distance
        speed = simulator.speed
        grade = sync.grade(atDistance: distance)
        command = sync.command(riderDistance: distance, riderSpeed: speed, videoTime: videoTime)
        if command == .finished {
            isRiding = false
            _ = try? await connection.send(.stop)
            return
        }
        await sendGrade(now: now, force: false)
    }

    /// Receives power from the trainer until the calling task is cancelled.
    public func listen() async {
        for await sample in await connection.samples() {
            if let power = sample.power { self.power = power }
        }
    }

    /// Sends the gradient when it changed by half a percent, at most once a second.
    private func sendGrade(now: Double, force: Bool) async {
        let percent = (grade.percent * 10).rounded() / 10
        if !force {
            if let sentGrade, abs(percent - sentGrade) < 0.5 { return }
            if now - sentAt < 1 { return }
        }
        do {
            try await connection.send(.setSimulation(grade: percent, windSpeed: 0))
            sentGrade = percent
            sentAt = now
        } catch {
            errorMessage = "The trainer did not take the gradient: \(error)"
        }
    }
}
