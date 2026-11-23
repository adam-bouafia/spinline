import Domain
import Foundation

/// The forces on a rider and bike on a road, and the speed a given power
/// produces.
///
/// Power at the pedals moves the bike against three resisting forces:
///
///     P * efficiency = v * (m * g * (Crr * cos(a) + sin(a)) + 0.5 * rho * CdA * v^2)
///
/// with `a` the slope angle, `m` rider plus bike, `Crr` rolling resistance,
/// `rho` air density and `CdA` the drag area. The first term is rolling and
/// climbing, the second is air drag, which grows with the cube of speed in
/// power terms. That cube is why a little more speed costs a lot more power.
public struct CyclingPhysics: Equatable, Sendable {
    /// Rider and bike, in kilograms.
    public var mass: Double
    /// Coefficient of rolling resistance (road tyres on asphalt: about 0.004).
    public var rollingResistance: Double
    /// Drag coefficient times frontal area, in square metres (hoods: about 0.32).
    public var dragArea: Double
    /// Air density in kg/m^3 (sea level, 15 degrees C: 1.225).
    public var airDensity: Double
    /// Share of pedal power that reaches the wheel (about 0.97 with a clean chain).
    public var drivetrainEfficiency: Double

    /// Standard gravity in m/s^2.
    public static let gravity = 9.806_65

    public init(
        mass: Double,
        rollingResistance: Double = 0.004,
        dragArea: Double = 0.32,
        airDensity: Double = 1.225,
        drivetrainEfficiency: Double = 0.97
    ) {
        self.mass = mass
        self.rollingResistance = rollingResistance
        self.dragArea = dragArea
        self.airDensity = airDensity
        self.drivetrainEfficiency = drivetrainEfficiency
    }

    public init(rider: RiderProfile) {
        self.init(mass: rider.totalMass)
    }

    /// The force opposing motion at `speed` (m/s), in newtons. Negative on a
    /// descent steep enough that gravity pushes harder than the road and the
    /// air hold back.
    public func resistingForce(atSpeed speed: Double, grade: Grade) -> Double {
        let angle = grade.angle
        let rollingAndClimbing = mass * Self.gravity * (rollingResistance * cos(angle) + sin(angle))
        let drag = 0.5 * airDensity * dragArea * speed * speed
        return rollingAndClimbing + drag
    }

    /// The pedal power, in watts, that holds a steady `speed` (m/s).
    public func power(atSpeed speed: Double, grade: Grade) -> Double {
        speed * resistingForce(atSpeed: speed, grade: grade) / drivetrainEfficiency
    }

    /// The steady speed, in m/s, that `power` watts hold on `grade`.
    ///
    /// Solved by bisection. For any power of zero or more the equation has
    /// one crossing from "not enough" to "too much", even downhill, where
    /// zero power gives the coasting speed.
    public func steadySpeed(power: Double, grade: Grade) -> Double {
        let target = max(power, 0)
        func excess(_ speed: Double) -> Double { self.power(atSpeed: speed, grade: grade) - target }

        var low = 0.0
        var high = 1.0
        while excess(high) <= 0, high < 1_000 { high *= 2 }
        for _ in 0..<100 {
            let middle = (low + high) / 2
            if excess(middle) <= 0 { low = middle } else { high = middle }
            if high - low < 1e-9 { break }
        }
        return (low + high) / 2
    }
}

extension Double {
    /// Metres per second to kilometres per hour.
    public var kilometresPerHour: Double { self * 3.6 }
    /// Kilometres per hour to metres per second.
    public var metresPerSecond: Double { self / 3.6 }
}
