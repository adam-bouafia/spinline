/// A 16-bit Bluetooth SIG assigned number for a GATT service or characteristic.
///
/// CoreBluetooth accepts the short form directly (`CBUUID(string: id.shortString)`).
public struct GATTIdentifier: Hashable, Sendable, CustomStringConvertible {
    public let value: UInt16

    public init(_ value: UInt16) {
        self.value = value
    }

    /// Four upper-case hex digits, for example `"1826"`.
    public var shortString: String {
        let hex = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: 4 - hex.count) + hex
    }

    public var description: String { "0x" + shortString }
}

/// Services this app talks to.
public enum GATTService {
    /// Fitness Machine Service (FTMS): smart trainers, treadmills, rowers.
    public static let fitnessMachine = GATTIdentifier(0x1826)
    /// Heart Rate Service: chest straps and watches.
    public static let heartRate = GATTIdentifier(0x180D)
    /// Cycling Power Service: power meters and older trainers.
    public static let cyclingPower = GATTIdentifier(0x1818)
}

/// Characteristics this app reads, writes or subscribes to.
public enum GATTCharacteristic {
    /// Fitness Machine Feature (read): what the machine measures and can be set to.
    public static let fitnessMachineFeature = GATTIdentifier(0x2ACC)
    /// Indoor Bike Data (notify): speed, cadence, power and more, about once a second.
    public static let indoorBikeData = GATTIdentifier(0x2AD2)
    /// Training Status (read, notify).
    public static let trainingStatus = GATTIdentifier(0x2AD3)
    /// Supported Power Range (read): minimum, maximum and step for ERG targets.
    public static let supportedPowerRange = GATTIdentifier(0x2AD8)
    /// Fitness Machine Control Point (write, indicate): commands and their results.
    public static let fitnessMachineControlPoint = GATTIdentifier(0x2AD9)
    /// Fitness Machine Status (notify): changes made by the machine or the user.
    public static let fitnessMachineStatus = GATTIdentifier(0x2ADA)
    /// Heart Rate Measurement (notify).
    public static let heartRateMeasurement = GATTIdentifier(0x2A37)
}
