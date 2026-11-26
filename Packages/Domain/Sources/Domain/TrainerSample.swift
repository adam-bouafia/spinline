/// One reading from a smart trainer or a sensor, in plain units.
///
/// Every field is optional: a trainer reports only what it measures, and a
/// heart-rate strap reports only the heart rate. Use ``merging(_:)`` to combine
/// readings from several devices into one sample.
public struct TrainerSample: Equatable, Sendable {
    /// Instantaneous power in watts.
    public var power: Int?
    /// Pedalling cadence in revolutions per minute.
    public var cadence: Double?
    /// Speed in kilometres per hour, as reported by the device.
    public var speed: Double?
    /// Distance since the start of the session, in metres.
    public var distance: Int?
    /// Heart rate in beats per minute.
    public var heartRate: Int?

    public init(
        power: Int? = nil,
        cadence: Double? = nil,
        speed: Double? = nil,
        distance: Int? = nil,
        heartRate: Int? = nil
    ) {
        self.power = power
        self.cadence = cadence
        self.speed = speed
        self.distance = distance
        self.heartRate = heartRate
    }

    /// A sample with this sample's values, and the other sample's values
    /// wherever this one has none.
    public func merging(_ other: TrainerSample) -> TrainerSample {
        TrainerSample(
            power: power ?? other.power,
            cadence: cadence ?? other.cadence,
            speed: speed ?? other.speed,
            distance: distance ?? other.distance,
            heartRate: heartRate ?? other.heartRate
        )
    }
}
