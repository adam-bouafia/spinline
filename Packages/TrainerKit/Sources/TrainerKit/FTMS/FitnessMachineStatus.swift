/// A notification on the Fitness Machine Status characteristic (`0x2ADA`):
/// the trainer reporting a change it made, or one the rider made on the
/// device. FTMS v1.0 section 4.17, table 4.26.
///
/// Only the values a bike app acts on have their own case; anything else
/// arrives as ``other(opCode:parameter:)`` so a new trainer never breaks the
/// client.
public enum FitnessMachineStatus: Equatable, Sendable {
    case reset
    case stoppedOrPausedByUser(StopOrPause)
    case stoppedBySafetyKey
    case startedOrResumedByUser
    case targetResistanceLevelChanged(Double)
    case targetPowerChanged(watts: Int)
    case indoorBikeSimulationChanged(IndoorBikeSimulation)
    /// The client lost control and must send Request Control again.
    case controlPermissionLost
    case other(opCode: UInt8, parameter: [UInt8])

    enum OpCode {
        static let reset: UInt8 = 0x01
        static let stoppedOrPausedByUser: UInt8 = 0x02
        static let stoppedBySafetyKey: UInt8 = 0x03
        static let startedOrResumedByUser: UInt8 = 0x04
        static let targetResistanceLevelChanged: UInt8 = 0x07
        static let targetPowerChanged: UInt8 = 0x08
        static let indoorBikeSimulationChanged: UInt8 = 0x12
        static let controlPermissionLost: UInt8 = 0xFF
    }

    public init(bytes: [UInt8]) throws(PacketError) {
        var reader = ByteReader(bytes)
        let opCode = try reader.read(UInt8.self)
        switch opCode {
        case OpCode.reset:
            self = .reset
        case OpCode.stoppedOrPausedByUser:
            let raw = try reader.read(UInt8.self)
            guard let control = StopOrPause(rawValue: raw) else {
                throw .reservedValue(field: "Stop or Pause control information", value: UInt32(raw))
            }
            self = .stoppedOrPausedByUser(control)
        case OpCode.stoppedBySafetyKey:
            self = .stoppedBySafetyKey
        case OpCode.startedOrResumedByUser:
            self = .startedOrResumedByUser
        case OpCode.targetResistanceLevelChanged:
            self = .targetResistanceLevelChanged(Scaled.value(try reader.read(UInt8.self), stepsPerUnit: 10))
        case OpCode.targetPowerChanged:
            self = .targetPowerChanged(watts: Int(try reader.read(Int16.self)))
        case OpCode.indoorBikeSimulationChanged:
            self = .indoorBikeSimulationChanged(try IndoorBikeSimulation(reader: &reader))
        case OpCode.controlPermissionLost:
            self = .controlPermissionLost
        default:
            self = .other(opCode: opCode, parameter: reader.readRemaining())
        }
    }

    public func encoded() -> [UInt8] {
        var writer = ByteWriter()
        switch self {
        case .reset:
            writer.write(OpCode.reset)
        case .stoppedOrPausedByUser(let control):
            writer.write(OpCode.stoppedOrPausedByUser)
            writer.write(control.rawValue)
        case .stoppedBySafetyKey:
            writer.write(OpCode.stoppedBySafetyKey)
        case .startedOrResumedByUser:
            writer.write(OpCode.startedOrResumedByUser)
        case .targetResistanceLevelChanged(let level):
            writer.write(OpCode.targetResistanceLevelChanged)
            writer.write(Scaled.raw(level, stepsPerUnit: 10, as: UInt8.self))
        case .targetPowerChanged(let watts):
            writer.write(OpCode.targetPowerChanged)
            writer.write(Int16(clamping: watts))
        case .indoorBikeSimulationChanged(let simulation):
            writer.write(OpCode.indoorBikeSimulationChanged)
            simulation.encode(into: &writer)
        case .controlPermissionLost:
            writer.write(OpCode.controlPermissionLost)
        case .other(let opCode, let parameter):
            writer.write(opCode)
            writer.write(contentsOf: parameter)
        }
        return writer.bytes
    }
}
