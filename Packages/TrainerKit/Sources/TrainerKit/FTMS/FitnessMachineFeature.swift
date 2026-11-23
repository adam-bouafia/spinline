/// The Fitness Machine Feature characteristic (`0x2ACC`): what a trainer
/// measures and which targets it accepts. Two 32-bit bit fields, FTMS v1.0
/// section 4.3.
///
/// A client reads this once after connecting and adapts: no ERG workouts
/// without ``TargetSettings/power``, no route gradients without
/// ``TargetSettings/indoorBikeSimulation``.
public struct FitnessMachineFeature: Equatable, Sendable {
    public var features: Features
    public var targetSettings: TargetSettings

    public init(features: Features, targetSettings: TargetSettings) {
        self.features = features
        self.targetSettings = targetSettings
    }

    /// The trainer can hold a target power (ERG mode).
    public var supportsERG: Bool { targetSettings.contains(.power) }

    /// The trainer can simulate a road gradient.
    public var supportsSimulation: Bool { targetSettings.contains(.indoorBikeSimulation) }

    public init(bytes: [UInt8]) throws(PacketError) {
        guard bytes.count >= 8 else {
            throw .unexpectedLength(expected: 8, actual: bytes.count)
        }
        var reader = ByteReader(bytes)
        features = Features(rawValue: try reader.read(UInt32.self))
        targetSettings = TargetSettings(rawValue: try reader.read(UInt32.self))
    }

    public func encoded() -> [UInt8] {
        var writer = ByteWriter()
        writer.write(features.rawValue)
        writer.write(targetSettings.rawValue)
        return writer.bytes
    }

    /// Fitness Machine Features field, FTMS v1.0 table 4.3.
    public struct Features: OptionSet, Hashable, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let averageSpeed = Features(rawValue: 1 << 0)
        public static let cadence = Features(rawValue: 1 << 1)
        public static let totalDistance = Features(rawValue: 1 << 2)
        public static let inclination = Features(rawValue: 1 << 3)
        public static let elevationGain = Features(rawValue: 1 << 4)
        public static let pace = Features(rawValue: 1 << 5)
        public static let stepCount = Features(rawValue: 1 << 6)
        public static let resistanceLevel = Features(rawValue: 1 << 7)
        public static let strideCount = Features(rawValue: 1 << 8)
        public static let expendedEnergy = Features(rawValue: 1 << 9)
        public static let heartRateMeasurement = Features(rawValue: 1 << 10)
        public static let metabolicEquivalent = Features(rawValue: 1 << 11)
        public static let elapsedTime = Features(rawValue: 1 << 12)
        public static let remainingTime = Features(rawValue: 1 << 13)
        public static let powerMeasurement = Features(rawValue: 1 << 14)
        public static let forceOnBeltAndPowerOutput = Features(rawValue: 1 << 15)
        public static let userDataRetention = Features(rawValue: 1 << 16)
    }

    /// Target Setting Features field, FTMS v1.0 table 4.4.
    public struct TargetSettings: OptionSet, Hashable, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let speed = TargetSettings(rawValue: 1 << 0)
        public static let inclination = TargetSettings(rawValue: 1 << 1)
        public static let resistance = TargetSettings(rawValue: 1 << 2)
        public static let power = TargetSettings(rawValue: 1 << 3)
        public static let heartRate = TargetSettings(rawValue: 1 << 4)
        public static let expendedEnergy = TargetSettings(rawValue: 1 << 5)
        public static let stepNumber = TargetSettings(rawValue: 1 << 6)
        public static let strideNumber = TargetSettings(rawValue: 1 << 7)
        public static let distance = TargetSettings(rawValue: 1 << 8)
        public static let trainingTime = TargetSettings(rawValue: 1 << 9)
        public static let timeInTwoHeartRateZones = TargetSettings(rawValue: 1 << 10)
        public static let timeInThreeHeartRateZones = TargetSettings(rawValue: 1 << 11)
        public static let timeInFiveHeartRateZones = TargetSettings(rawValue: 1 << 12)
        public static let indoorBikeSimulation = TargetSettings(rawValue: 1 << 13)
        public static let wheelCircumference = TargetSettings(rawValue: 1 << 14)
        public static let spinDown = TargetSettings(rawValue: 1 << 15)
        public static let cadence = TargetSettings(rawValue: 1 << 16)
    }
}

/// The Supported Power Range characteristic (`0x2AD8`): the limits of ERG
/// mode. GATT Specification Supplement section 3.230.
public struct SupportedPowerRange: Equatable, Sendable {
    public var minimum: Int
    public var maximum: Int
    /// The smallest step between two targets, in watts.
    public var increment: Int

    public init(minimum: Int, maximum: Int, increment: Int) {
        self.minimum = minimum
        self.maximum = maximum
        self.increment = increment
    }

    public init(bytes: [UInt8]) throws(PacketError) {
        guard bytes.count >= 6 else {
            throw .unexpectedLength(expected: 6, actual: bytes.count)
        }
        var reader = ByteReader(bytes)
        minimum = Int(try reader.read(Int16.self))
        maximum = Int(try reader.read(Int16.self))
        increment = Int(try reader.read(UInt16.self))
    }

    public func encoded() -> [UInt8] {
        var writer = ByteWriter()
        writer.write(Int16(clamping: minimum))
        writer.write(Int16(clamping: maximum))
        writer.write(UInt16(clamping: increment))
        return writer.bytes
    }

    /// The nearest target the trainer accepts: clamped to the range, then
    /// rounded to a whole number of increments above the minimum.
    public func validTarget(near watts: Int) -> Int {
        let clamped = min(max(watts, minimum), maximum)
        guard increment > 1 else { return clamped }
        let steps = (Double(clamped - minimum) / Double(increment)).rounded()
        return min(minimum + Int(steps) * increment, maximum)
    }
}
