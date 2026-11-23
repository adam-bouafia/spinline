/// The rider: what the physics and the workouts need to know.
public struct RiderProfile: Equatable, Sendable, Codable {
    /// Body mass in kilograms.
    public var riderMass: Double
    /// Bike mass in kilograms.
    public var bikeMass: Double
    /// Functional threshold power in watts: the power the rider can hold for
    /// about an hour. Workout targets are fractions of it.
    public var ftp: Int

    public init(riderMass: Double = 75, bikeMass: Double = 8, ftp: Int = 200) {
        self.riderMass = riderMass
        self.bikeMass = bikeMass
        self.ftp = ftp
    }

    /// Rider and bike together, the mass the legs have to move.
    public var totalMass: Double { riderMass + bikeMass }
}
