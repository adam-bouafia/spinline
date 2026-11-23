import Domain

/// The Heart Rate Measurement characteristic (`0x2A37`) of the Heart Rate
/// Service. GATT Specification Supplement section 3.126.
///
/// One flags byte, the heart rate as one or two bytes, then optional energy
/// and any number of RR intervals.
public struct HeartRateMeasurement: Equatable, Sendable {
    /// Beats per minute.
    public var heartRate: Int
    public var sensorContact: SensorContact
    /// Accumulated energy as the sensor reports it. The GATT Specification
    /// Supplement gives the unit as joules; some older texts say kilojoules.
    public var energyExpended: Int?
    /// Time between consecutive beats in seconds, oldest first (sent in
    /// steps of 1/1024 s). Used for heart rate variability.
    public var rrIntervals: [Double]

    public init(
        heartRate: Int,
        sensorContact: SensorContact = .notSupported,
        energyExpended: Int? = nil,
        rrIntervals: [Double] = []
    ) {
        self.heartRate = heartRate
        self.sensorContact = sensorContact
        self.energyExpended = energyExpended
        self.rrIntervals = rrIntervals
    }

    public enum SensorContact: Equatable, Sendable {
        /// The sensor cannot tell whether it touches the skin.
        case notSupported
        /// The sensor has no skin contact; the heart rate may be stale.
        case notDetected
        case detected
    }

    public var sample: TrainerSample {
        TrainerSample(heartRate: heartRate)
    }

    enum Flag {
        static let sixteenBitValue: UInt8 = 1 << 0
        static let contactDetected: UInt8 = 1 << 1
        static let contactSupported: UInt8 = 1 << 2
        static let energyExpended: UInt8 = 1 << 3
        static let rrIntervals: UInt8 = 1 << 4
    }

    public init(bytes: [UInt8]) throws(PacketError) {
        var reader = ByteReader(bytes)
        let flags = try reader.read(UInt8.self)

        if flags & Flag.sixteenBitValue != 0 {
            heartRate = Int(try reader.read(UInt16.self))
        } else {
            heartRate = Int(try reader.read(UInt8.self))
        }

        if flags & Flag.contactSupported == 0 {
            sensorContact = .notSupported
        } else {
            sensorContact = flags & Flag.contactDetected != 0 ? .detected : .notDetected
        }

        energyExpended = flags & Flag.energyExpended != 0 ? Int(try reader.read(UInt16.self)) : nil

        rrIntervals = []
        if flags & Flag.rrIntervals != 0 {
            // The count is not sent: every remaining pair of bytes is one interval.
            while reader.remainingCount >= 2 {
                rrIntervals.append(Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 1024))
            }
        }
    }

    /// The notification a sensor would send. The heart rate uses one byte
    /// when it fits, as sensors do.
    public func encoded() -> [UInt8] {
        var flags: UInt8 = 0
        let sixteenBit = heartRate > Int(UInt8.max)
        if sixteenBit { flags |= Flag.sixteenBitValue }
        switch sensorContact {
        case .notSupported: break
        case .notDetected: flags |= Flag.contactSupported
        case .detected: flags |= Flag.contactSupported | Flag.contactDetected
        }
        if energyExpended != nil { flags |= Flag.energyExpended }
        if !rrIntervals.isEmpty { flags |= Flag.rrIntervals }

        var writer = ByteWriter()
        writer.write(flags)
        if sixteenBit {
            writer.write(UInt16(clamping: heartRate))
        } else {
            writer.write(UInt8(clamping: heartRate))
        }
        if let energyExpended {
            writer.write(UInt16(clamping: energyExpended))
        }
        for interval in rrIntervals {
            writer.write(Scaled.raw(interval, stepsPerUnit: 1024, as: UInt16.self))
        }
        return writer.bytes
    }
}
