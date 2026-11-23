/// Moves a virtual rider along a road, one time step at a time.
///
/// Speed does not jump to the steady value: the bike has mass, so it speeds
/// up and slows down. Each step applies the work-energy rule: kinetic energy
/// grows by the power that reaches the wheel and shrinks by the power the
/// resisting forces take,
///
///     E(t + dt) = E(t) + (P * efficiency - F(v) * v) * dt,   v = sqrt(2 * E / m)
///
/// Working in energy keeps the step stable at zero speed, where a force
/// form (F = P / v) would divide by zero.
public struct RideSimulator: Equatable, Sendable {
    public var physics: CyclingPhysics
    /// Current speed in m/s.
    public private(set) var speed: Double
    /// Distance ridden in metres.
    public private(set) var distance: Double

    public init(physics: CyclingPhysics, speed: Double = 0, distance: Double = 0) {
        self.physics = physics
        self.speed = max(speed, 0)
        self.distance = distance
    }

    /// Advances by `duration` seconds at `power` watts on `grade`.
    public mutating func advance(power: Double, grade: Grade, duration: Double) {
        guard duration > 0 else { return }
        let mass = physics.mass
        let force = physics.resistingForce(atSpeed: speed, grade: grade)
        var energy = 0.5 * mass * speed * speed
        energy += (max(power, 0) * physics.drivetrainEfficiency - force * speed) * duration

        // At rest the term above is zero; on a descent where gravity beats the
        // rolling resistance the bike still starts to roll.
        if speed == 0, force < 0 {
            let gained = -force / mass * duration
            energy += 0.5 * mass * gained * gained
        }

        let newSpeed = (2 * max(energy, 0) / mass).squareRoot()
        distance += (speed + newSpeed) / 2 * duration
        speed = newSpeed
    }
}
