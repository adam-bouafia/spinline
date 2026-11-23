import Domain
import RideEngine
import Testing

struct CyclingPhysicsTests {
    /// 75 kg rider on an 8 kg bike, default constants.
    let physics = CyclingPhysics(rider: RiderProfile(riderMass: 75, bikeMass: 8, ftp: 250))

    /// Reference speeds computed independently (Python, bisection on the same
    /// equation with the same constants), in m/s.
    @Test(arguments: [
        (200.0, 0.0, 9.410873),
        (300.0, 0.0, 10.923013),
        (200.0, 5.0, 4.109430),
        (250.0, 8.0, 3.440943),
        (100.0, -2.0, 10.629672),
        (0.0, -5.0, 13.812719),
    ])
    func steadySpeedMatchesReference(power: Double, gradePercent: Double, expected: Double) {
        let speed = physics.steadySpeed(power: power, grade: Grade(percent: gradePercent))
        #expect(abs(speed - expected) < 1e-5)
    }

    @Test func powerAndSpeedAreInverses() {
        for speed in stride(from: 2.0, through: 15, by: 0.5) {
            let power = physics.power(atSpeed: speed, grade: Grade(percent: 3))
            #expect(abs(physics.steadySpeed(power: power, grade: Grade(percent: 3)) - speed) < 1e-6)
        }
    }

    @Test func morePowerIsAlwaysFaster() {
        var previous = 0.0
        for watts in stride(from: 50.0, through: 600, by: 50) {
            let speed = physics.steadySpeed(power: watts, grade: .flat)
            #expect(speed > previous)
            previous = speed
        }
    }

    @Test func climbingIsSlowerThanTheFlat() {
        let flat = physics.steadySpeed(power: 250, grade: .flat)
        let climb = physics.steadySpeed(power: 250, grade: Grade(percent: 6))
        #expect(climb < flat / 2)
    }

    @Test func zeroPowerOnTheFlatStandsStill() {
        #expect(physics.steadySpeed(power: 0, grade: .flat) < 1e-6)
    }

    @Test func negativePowerIsTreatedAsZero() {
        #expect(physics.steadySpeed(power: -100, grade: .flat) == physics.steadySpeed(power: 0, grade: .flat))
    }

    @Test func unitConversions() {
        #expect(10.0.kilometresPerHour == 36)
        #expect(36.0.metresPerSecond == 10)
    }
}

struct RideSimulatorTests {
    let physics = CyclingPhysics(mass: 83)

    @Test func speedApproachesTheSteadyValue() {
        var ride = RideSimulator(physics: physics)
        for _ in 0..<600 { ride.advance(power: 200, grade: .flat, duration: 0.5) }
        #expect(abs(ride.speed - physics.steadySpeed(power: 200, grade: .flat)) < 0.01)
    }

    @Test func speedDoesNotJump() {
        var ride = RideSimulator(physics: physics)
        ride.advance(power: 400, grade: .flat, duration: 1)
        #expect(ride.speed > 0)
        #expect(ride.speed < physics.steadySpeed(power: 400, grade: .flat) / 2)
    }

    @Test func stoppingPedallingSlowsTheRiderDown() {
        var ride = RideSimulator(physics: physics, speed: 10)
        ride.advance(power: 0, grade: .flat, duration: 5)
        #expect(ride.speed < 10)
        #expect(ride.speed > 5)
    }

    @Test func aClimbWithoutPowerStopsTheBikeWithoutRollingBack() {
        var ride = RideSimulator(physics: physics, speed: 3)
        for _ in 0..<60 { ride.advance(power: 0, grade: Grade(percent: 8), duration: 1) }
        #expect(ride.speed == 0)
        #expect(ride.distance > 0)
    }

    @Test func aSteepDescentStartsRollingFromRest() {
        var ride = RideSimulator(physics: physics)
        ride.advance(power: 0, grade: Grade(percent: -6), duration: 1)
        #expect(ride.speed > 0)
    }

    @Test func aGentleSlopeHeldByRollingResistanceStaysAtRest() {
        // sin(atan(0.2 %)) is below Crr 0.004, so the bike does not move.
        var ride = RideSimulator(physics: physics)
        ride.advance(power: 0, grade: Grade(percent: -0.2), duration: 10)
        #expect(ride.speed == 0)
    }

    @Test func distanceIsTheIntegralOfSpeed() {
        var ride = RideSimulator(physics: physics, speed: 10)
        // Hold speed: feed exactly the power that keeps 10 m/s.
        let holding = physics.power(atSpeed: 10, grade: .flat)
        for _ in 0..<60 { ride.advance(power: holding, grade: .flat, duration: 1) }
        #expect(abs(ride.distance - 600) < 0.5)
    }
}
