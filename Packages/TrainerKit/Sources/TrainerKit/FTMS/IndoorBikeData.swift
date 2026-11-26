import Domain

/// The Indoor Bike Data characteristic (`0x2AD2`) of the Fitness Machine
/// Service: what a smart trainer reports, usually once a second.
///
/// The packet starts with a 16-bit flags field. Each flag announces one field,
/// and fields follow in a fixed order, so the flags alone tell a decoder where
/// every value sits. Absent fields are `nil` here.
///
/// Sources: FTMS v1.0 section 4.9 and the GATT Specification Supplement
/// (2026-09-09) section 3.139.
public struct IndoorBikeData: Equatable, Sendable {
    /// Instantaneous speed in km/h, resolution 0.01. Absent when the flags'
    /// More Data bit is set (the record continues in a later notification).
    public var instantaneousSpeed: Double?
    /// Average speed since the start of the session in km/h, resolution 0.01.
    public var averageSpeed: Double?
    /// Instantaneous cadence in rpm, resolution 0.5.
    public var instantaneousCadence: Double?
    /// Average cadence in rpm, resolution 0.5.
    public var averageCadence: Double?
    /// Distance since the start of the session in metres (24 bits).
    public var totalDistance: UInt32?
    /// Current resistance level, unitless. See ``ResistanceLevelFormat``.
    public var resistanceLevel: Int?
    /// Instantaneous power in watts.
    public var instantaneousPower: Int?
    /// Average power since the start of the session in watts.
    public var averagePower: Int?
    /// Expended energy; the three values travel together.
    public var expendedEnergy: ExpendedEnergy?
    /// Heart rate in beats per minute, when the trainer forwards one.
    public var heartRate: Int?
    /// Metabolic equivalent, resolution 0.1.
    public var metabolicEquivalent: Double?
    /// Seconds since the start of the session.
    public var elapsedTime: Int?
    /// Seconds left in the session.
    public var remainingTime: Int?

    public init(
        instantaneousSpeed: Double? = nil,
        averageSpeed: Double? = nil,
        instantaneousCadence: Double? = nil,
        averageCadence: Double? = nil,
        totalDistance: UInt32? = nil,
        resistanceLevel: Int? = nil,
        instantaneousPower: Int? = nil,
        averagePower: Int? = nil,
        expendedEnergy: ExpendedEnergy? = nil,
        heartRate: Int? = nil,
        metabolicEquivalent: Double? = nil,
        elapsedTime: Int? = nil,
        remainingTime: Int? = nil
    ) {
        self.instantaneousSpeed = instantaneousSpeed
        self.averageSpeed = averageSpeed
        self.instantaneousCadence = instantaneousCadence
        self.averageCadence = averageCadence
        self.totalDistance = totalDistance
        self.resistanceLevel = resistanceLevel
        self.instantaneousPower = instantaneousPower
        self.averagePower = averagePower
        self.expendedEnergy = expendedEnergy
        self.heartRate = heartRate
        self.metabolicEquivalent = metabolicEquivalent
        self.elapsedTime = elapsedTime
        self.remainingTime = remainingTime
    }

    /// The flags that describe this record's fields.
    public var flags: Flags {
        var flags: Flags = []
        if instantaneousSpeed == nil { flags.insert(.moreData) }
        if averageSpeed != nil { flags.insert(.averageSpeed) }
        if instantaneousCadence != nil { flags.insert(.instantaneousCadence) }
        if averageCadence != nil { flags.insert(.averageCadence) }
        if totalDistance != nil { flags.insert(.totalDistance) }
        if resistanceLevel != nil { flags.insert(.resistanceLevel) }
        if instantaneousPower != nil { flags.insert(.instantaneousPower) }
        if averagePower != nil { flags.insert(.averagePower) }
        if expendedEnergy != nil { flags.insert(.expendedEnergy) }
        if heartRate != nil { flags.insert(.heartRate) }
        if metabolicEquivalent != nil { flags.insert(.metabolicEquivalent) }
        if elapsedTime != nil { flags.insert(.elapsedTime) }
        if remainingTime != nil { flags.insert(.remainingTime) }
        return flags
    }

    /// The values the rest of the app uses.
    public var sample: TrainerSample {
        TrainerSample(
            power: instantaneousPower,
            cadence: instantaneousCadence,
            speed: instantaneousSpeed,
            distance: totalDistance.map(Int.init),
            heartRate: heartRate
        )
    }
}

// MARK: - Flags and nested types

extension IndoorBikeData {
    /// The 16-bit flags field. Bit 0 is inverted: when More Data is 0 the
    /// Instantaneous Speed field is present. Every other bit set to 1 means
    /// its field is present. (Table 4.10 of FTMS v1.0 prints bit 2 the other
    /// way round; the GATT Specification Supplement says 1 means "cadence
    /// present", and so does this code.)
    public struct Flags: OptionSet, Hashable, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static let moreData = Flags(rawValue: 1 << 0)
        public static let averageSpeed = Flags(rawValue: 1 << 1)
        public static let instantaneousCadence = Flags(rawValue: 1 << 2)
        public static let averageCadence = Flags(rawValue: 1 << 3)
        public static let totalDistance = Flags(rawValue: 1 << 4)
        public static let resistanceLevel = Flags(rawValue: 1 << 5)
        public static let instantaneousPower = Flags(rawValue: 1 << 6)
        public static let averagePower = Flags(rawValue: 1 << 7)
        public static let expendedEnergy = Flags(rawValue: 1 << 8)
        public static let heartRate = Flags(rawValue: 1 << 9)
        public static let metabolicEquivalent = Flags(rawValue: 1 << 10)
        public static let elapsedTime = Flags(rawValue: 1 << 11)
        public static let remainingTime = Flags(rawValue: 1 << 12)
    }

    /// Total energy, energy per hour and energy per minute, in kilocalories.
    /// `nil` stands for the specification's "Data Not Available" values
    /// (0xFFFF, 0xFFFF and 0xFF).
    public struct ExpendedEnergy: Equatable, Sendable {
        public var total: Int?
        public var perHour: Int?
        public var perMinute: Int?

        public init(total: Int? = nil, perHour: Int? = nil, perMinute: Int? = nil) {
            self.total = total
            self.perHour = perHour
            self.perMinute = perMinute
        }
    }

    /// How the Resistance Level field is encoded.
    ///
    /// The specifications disagree. FTMS v1.0 points to the 2017 assigned
    /// numbers, which define a 2-byte `sint16`, and existing implementations
    /// (for example qdomyos-zwift) send two bytes. The GATT Specification
    /// Supplement of 2026-09-09 lists a
    /// 1-byte `uint8`. Because every other field has a fixed size, the packet
    /// length tells the two apart, and the decoder accepts both.
    public enum ResistanceLevelFormat: Sendable {
        /// Two bytes, signed (FTMS v1.0 and deployed trainers).
        case sint16
        /// One byte, unsigned (GATT Specification Supplement, 2026).
        case uint8

        var byteCount: Int {
            switch self {
            case .sint16: 2
            case .uint8: 1
            }
        }
    }
}

// MARK: - Decoding

extension IndoorBikeData {
    /// Decodes one notification.
    ///
    /// Bytes after the last announced field are ignored: some devices pad
    /// their packets, and a client should accept what it can understand.
    ///
    /// - Throws: ``PacketError/truncated(offset:needed:)`` when the packet ends
    ///   before a field its flags announce.
    public init(bytes: [UInt8]) throws(PacketError) {
        var reader = ByteReader(bytes)
        let flags = Flags(rawValue: try reader.read(UInt16.self))
        let resistanceFormat = Self.resistanceLevelFormat(flags: flags, packetLength: bytes.count)
        self.init()

        if !flags.contains(.moreData) {
            instantaneousSpeed = Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 100)
        }
        if flags.contains(.averageSpeed) {
            averageSpeed = Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 100)
        }
        if flags.contains(.instantaneousCadence) {
            instantaneousCadence = Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 2)
        }
        if flags.contains(.averageCadence) {
            averageCadence = Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 2)
        }
        if flags.contains(.totalDistance) {
            totalDistance = try reader.readUInt24()
        }
        if flags.contains(.resistanceLevel) {
            switch resistanceFormat {
            case .sint16: resistanceLevel = Int(try reader.read(Int16.self))
            case .uint8: resistanceLevel = Int(try reader.read(UInt8.self))
            }
        }
        if flags.contains(.instantaneousPower) {
            instantaneousPower = Int(try reader.read(Int16.self))
        }
        if flags.contains(.averagePower) {
            averagePower = Int(try reader.read(Int16.self))
        }
        if flags.contains(.expendedEnergy) {
            let total = try reader.read(UInt16.self)
            let perHour = try reader.read(UInt16.self)
            let perMinute = try reader.read(UInt8.self)
            expendedEnergy = ExpendedEnergy(
                total: total == .max ? nil : Int(total),
                perHour: perHour == .max ? nil : Int(perHour),
                perMinute: perMinute == .max ? nil : Int(perMinute)
            )
        }
        if flags.contains(.heartRate) {
            heartRate = Int(try reader.read(UInt8.self))
        }
        if flags.contains(.metabolicEquivalent) {
            metabolicEquivalent = Scaled.value(try reader.read(UInt8.self), stepsPerUnit: 10)
        }
        if flags.contains(.elapsedTime) {
            elapsedTime = Int(try reader.read(UInt16.self))
        }
        if flags.contains(.remainingTime) {
            remainingTime = Int(try reader.read(UInt16.self))
        }
    }

    /// The packet length that `flags` announces, flags field included.
    static func announcedLength(flags: Flags, resistanceLevelFormat: ResistanceLevelFormat) -> Int {
        var length = 2
        if !flags.contains(.moreData) { length += 2 }
        if flags.contains(.averageSpeed) { length += 2 }
        if flags.contains(.instantaneousCadence) { length += 2 }
        if flags.contains(.averageCadence) { length += 2 }
        if flags.contains(.totalDistance) { length += 3 }
        if flags.contains(.resistanceLevel) { length += resistanceLevelFormat.byteCount }
        if flags.contains(.instantaneousPower) { length += 2 }
        if flags.contains(.averagePower) { length += 2 }
        if flags.contains(.expendedEnergy) { length += 5 }
        if flags.contains(.heartRate) { length += 1 }
        if flags.contains(.metabolicEquivalent) { length += 1 }
        if flags.contains(.elapsedTime) { length += 2 }
        if flags.contains(.remainingTime) { length += 2 }
        return length
    }

    /// One byte for resistance only when the packet is exactly that long;
    /// otherwise the two-byte form that deployed trainers use.
    static func resistanceLevelFormat(flags: Flags, packetLength: Int) -> ResistanceLevelFormat {
        guard flags.contains(.resistanceLevel) else { return .sint16 }
        let compact = announcedLength(flags: flags, resistanceLevelFormat: .uint8)
        return packetLength == compact ? .uint8 : .sint16
    }
}

// MARK: - Encoding

extension IndoorBikeData {
    /// The notification a trainer would send for this record. Values outside
    /// a field's range are clamped to it.
    public func encoded(resistanceLevelFormat: ResistanceLevelFormat = .sint16) -> [UInt8] {
        var writer = ByteWriter()
        writer.write(flags.rawValue)
        if let instantaneousSpeed {
            writer.write(Scaled.raw(instantaneousSpeed, stepsPerUnit: 100, as: UInt16.self))
        }
        if let averageSpeed {
            writer.write(Scaled.raw(averageSpeed, stepsPerUnit: 100, as: UInt16.self))
        }
        if let instantaneousCadence {
            writer.write(Scaled.raw(instantaneousCadence, stepsPerUnit: 2, as: UInt16.self))
        }
        if let averageCadence {
            writer.write(Scaled.raw(averageCadence, stepsPerUnit: 2, as: UInt16.self))
        }
        if let totalDistance {
            writer.writeUInt24(min(totalDistance, 0xFF_FFFF))
        }
        if let resistanceLevel {
            switch resistanceLevelFormat {
            case .sint16: writer.write(Int16(clamping: resistanceLevel))
            case .uint8: writer.write(UInt8(clamping: resistanceLevel))
            }
        }
        if let instantaneousPower {
            writer.write(Int16(clamping: instantaneousPower))
        }
        if let averagePower {
            writer.write(Int16(clamping: averagePower))
        }
        if let expendedEnergy {
            writer.write(expendedEnergy.total.map { UInt16(clamping: $0) } ?? .max)
            writer.write(expendedEnergy.perHour.map { UInt16(clamping: $0) } ?? .max)
            writer.write(expendedEnergy.perMinute.map { UInt8(clamping: $0) } ?? .max)
        }
        if let heartRate {
            writer.write(UInt8(clamping: heartRate))
        }
        if let metabolicEquivalent {
            writer.write(Scaled.raw(metabolicEquivalent, stepsPerUnit: 10, as: UInt8.self))
        }
        if let elapsedTime {
            writer.write(UInt16(clamping: elapsedTime))
        }
        if let remainingTime {
            writer.write(UInt16(clamping: remainingTime))
        }
        return writer.bytes
    }
}
