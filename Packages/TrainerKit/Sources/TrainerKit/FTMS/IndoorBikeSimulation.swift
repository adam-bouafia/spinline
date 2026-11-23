/// The road a trainer simulates in simulation mode: the parameter of Set
/// Indoor Bike Simulation Parameters (op code `0x11`), FTMS v1.0 table 4.20.
///
/// The trainer combines these with the measured speed to set its resistance,
/// so a 6 % climb feels like one.
public struct IndoorBikeSimulation: Equatable, Sendable {
    /// Wind speed in metres per second, resolution 0.001.
    public var windSpeed: Double
    /// Gradient in percent, resolution 0.01. Negative is downhill.
    public var grade: Double
    /// Coefficient of rolling resistance (Crr), unitless, resolution 0.0001.
    public var rollingResistance: Double
    /// Wind resistance coefficient (Cw) in kg/m, resolution 0.01. The
    /// specification gives no formula; read as drag force = Cw * v^2, it is
    /// half the air density times the rider's drag area (CdA).
    public var windResistance: Double

    /// The defaults describe a road bike on asphalt: Crr 0.004, and Cw 0.20,
    /// which is 0.5 * 1.225 kg/m^3 * 0.32 m^2 rounded to the field's 0.01 step.
    public init(
        windSpeed: Double = 0,
        grade: Double = 0,
        rollingResistance: Double = 0.004,
        windResistance: Double = 0.20
    ) {
        self.windSpeed = windSpeed
        self.grade = grade
        self.rollingResistance = rollingResistance
        self.windResistance = windResistance
    }

    static let byteCount = 6

    func encode(into writer: inout ByteWriter) {
        writer.write(Scaled.raw(windSpeed, stepsPerUnit: 1000, as: Int16.self))
        writer.write(Scaled.raw(grade, stepsPerUnit: 100, as: Int16.self))
        writer.write(Scaled.raw(rollingResistance, stepsPerUnit: 10_000, as: UInt8.self))
        writer.write(Scaled.raw(windResistance, stepsPerUnit: 100, as: UInt8.self))
    }

    init(reader: inout ByteReader) throws(PacketError) {
        windSpeed = Scaled.value(try reader.read(Int16.self), stepsPerUnit: 1000)
        grade = Scaled.value(try reader.read(Int16.self), stepsPerUnit: 100)
        rollingResistance = Scaled.value(try reader.read(UInt8.self), stepsPerUnit: 10_000)
        windResistance = Scaled.value(try reader.read(UInt8.self), stepsPerUnit: 100)
    }
}
