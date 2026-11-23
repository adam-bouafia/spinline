/// Op codes of the Fitness Machine Control Point (`0x2AD9`), FTMS v1.0 table 4.15.
public enum ControlPointOpCode: UInt8, Sendable, CaseIterable {
    case requestControl = 0x00
    case reset = 0x01
    case setTargetSpeed = 0x02
    case setTargetInclination = 0x03
    case setTargetResistanceLevel = 0x04
    case setTargetPower = 0x05
    case setTargetHeartRate = 0x06
    case startOrResume = 0x07
    case stopOrPause = 0x08
    case setIndoorBikeSimulationParameters = 0x11
    case setWheelCircumference = 0x12
    case setTargetedCadence = 0x14
    /// Not a command: the first byte of every response the trainer indicates.
    case responseCode = 0x80
}

/// The parameter of the Stop or Pause command, FTMS v1.0 table 4.16.
public enum StopOrPause: UInt8, Sendable {
    case stop = 0x01
    case pause = 0x02
}

/// A command a client writes to the Fitness Machine Control Point.
///
/// The protocol, in short: subscribe to indications on the control point,
/// write ``requestControl``, wait for its success response, then send other
/// commands one at a time. The trainer answers each write with a
/// ``ControlPointResponse`` indication. Control lasts until the connection
/// drops, the trainer reports Control Permission Lost, or the client resets.
public enum ControlPointCommand: Equatable, Sendable {
    case requestControl
    case reset
    /// Target speed in km/h, resolution 0.01.
    case setTargetSpeed(kilometresPerHour: Double)
    /// Target inclination in percent, resolution 0.1.
    case setTargetInclination(percent: Double)
    /// Target resistance level, unitless, resolution 0.1.
    case setTargetResistanceLevel(Double)
    /// ERG mode: the trainer holds this power whatever the cadence.
    case setTargetPower(watts: Int)
    /// Target heart rate in beats per minute.
    case setTargetHeartRate(beatsPerMinute: Int)
    case startOrResume
    case stopOrPause(StopOrPause)
    /// Simulation mode: the trainer turns a virtual road into resistance.
    case setIndoorBikeSimulation(IndoorBikeSimulation)
    /// Wheel circumference in millimetres, resolution 0.1.
    case setWheelCircumference(millimetres: Double)
    /// Targeted cadence in rpm, resolution 0.5.
    case setTargetedCadence(revolutionsPerMinute: Double)

    public var opCode: ControlPointOpCode {
        switch self {
        case .requestControl: .requestControl
        case .reset: .reset
        case .setTargetSpeed: .setTargetSpeed
        case .setTargetInclination: .setTargetInclination
        case .setTargetResistanceLevel: .setTargetResistanceLevel
        case .setTargetPower: .setTargetPower
        case .setTargetHeartRate: .setTargetHeartRate
        case .startOrResume: .startOrResume
        case .stopOrPause: .stopOrPause
        case .setIndoorBikeSimulation: .setIndoorBikeSimulationParameters
        case .setWheelCircumference: .setWheelCircumference
        case .setTargetedCadence: .setTargetedCadence
        }
    }

    /// The bytes to write: the op code, then its parameter, little-endian.
    public func encoded() -> [UInt8] {
        var writer = ByteWriter()
        writer.write(opCode.rawValue)
        switch self {
        case .requestControl, .reset, .startOrResume:
            break
        case .setTargetSpeed(let speed):
            writer.write(Scaled.raw(speed, stepsPerUnit: 100, as: UInt16.self))
        case .setTargetInclination(let percent):
            writer.write(Scaled.raw(percent, stepsPerUnit: 10, as: Int16.self))
        case .setTargetResistanceLevel(let level):
            writer.write(Scaled.raw(level, stepsPerUnit: 10, as: UInt8.self))
        case .setTargetPower(let watts):
            writer.write(Int16(clamping: watts))
        case .setTargetHeartRate(let beatsPerMinute):
            writer.write(UInt8(clamping: beatsPerMinute))
        case .stopOrPause(let control):
            writer.write(control.rawValue)
        case .setIndoorBikeSimulation(let simulation):
            simulation.encode(into: &writer)
        case .setWheelCircumference(let millimetres):
            writer.write(Scaled.raw(millimetres, stepsPerUnit: 10, as: UInt16.self))
        case .setTargetedCadence(let rpm):
            writer.write(Scaled.raw(rpm, stepsPerUnit: 2, as: UInt16.self))
        }
        return writer.bytes
    }

    /// Decodes a write, as a trainer does. Used by the virtual trainer.
    ///
    /// Strict on purpose: the parameter must have exactly the size its op code
    /// defines, so a client bug shows up as an Invalid Parameter response.
    public init(bytes: [UInt8]) throws(PacketError) {
        var reader = ByteReader(bytes)
        let rawOpCode = try reader.read(UInt8.self)
        guard let opCode = ControlPointOpCode(rawValue: rawOpCode), opCode != .responseCode else {
            throw .unknownOpCode(rawOpCode)
        }
        let expected = 1 + Self.parameterSize(of: opCode)
        guard bytes.count == expected else {
            throw .unexpectedLength(expected: expected, actual: bytes.count)
        }

        switch opCode {
        case .requestControl: self = .requestControl
        case .reset: self = .reset
        case .startOrResume: self = .startOrResume
        case .setTargetSpeed:
            self = .setTargetSpeed(kilometresPerHour: Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 100))
        case .setTargetInclination:
            self = .setTargetInclination(percent: Scaled.value(try reader.read(Int16.self), stepsPerUnit: 10))
        case .setTargetResistanceLevel:
            self = .setTargetResistanceLevel(Scaled.value(try reader.read(UInt8.self), stepsPerUnit: 10))
        case .setTargetPower:
            self = .setTargetPower(watts: Int(try reader.read(Int16.self)))
        case .setTargetHeartRate:
            self = .setTargetHeartRate(beatsPerMinute: Int(try reader.read(UInt8.self)))
        case .stopOrPause:
            let raw = try reader.read(UInt8.self)
            guard let control = StopOrPause(rawValue: raw) else {
                throw .reservedValue(field: "Stop or Pause control information", value: UInt32(raw))
            }
            self = .stopOrPause(control)
        case .setIndoorBikeSimulationParameters:
            self = .setIndoorBikeSimulation(try IndoorBikeSimulation(reader: &reader))
        case .setWheelCircumference:
            self = .setWheelCircumference(millimetres: Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 10))
        case .setTargetedCadence:
            self = .setTargetedCadence(
                revolutionsPerMinute: Scaled.value(try reader.read(UInt16.self), stepsPerUnit: 2))
        case .responseCode:
            throw .unknownOpCode(rawOpCode)
        }
    }

    static func parameterSize(of opCode: ControlPointOpCode) -> Int {
        switch opCode {
        case .requestControl, .reset, .startOrResume, .responseCode: 0
        case .setTargetResistanceLevel, .setTargetHeartRate, .stopOrPause: 1
        case .setTargetSpeed, .setTargetInclination, .setTargetPower, .setWheelCircumference,
            .setTargetedCadence:
            2
        case .setIndoorBikeSimulationParameters: IndoorBikeSimulation.byteCount
        }
    }
}

/// Result codes of a control point response, FTMS v1.0 table 4.24.
public enum ControlPointResultCode: UInt8, Sendable {
    case success = 0x01
    case opCodeNotSupported = 0x02
    case invalidParameter = 0x03
    case operationFailed = 0x04
    case controlNotPermitted = 0x05
}

/// The trainer's answer to a control point write, sent as an indication:
/// `0x80`, the op code it answers, a result code.
public struct ControlPointResponse: Equatable, Sendable {
    /// The op code of the command this answers. Raw, because a trainer may
    /// answer an op code this codec does not know with Op Code Not Supported.
    public var requestOpCode: UInt8
    public var result: ControlPointResultCode
    /// Extra data; only the spin down procedure defines any.
    public var parameter: [UInt8]

    public init(requestOpCode: UInt8, result: ControlPointResultCode, parameter: [UInt8] = []) {
        self.requestOpCode = requestOpCode
        self.result = result
        self.parameter = parameter
    }

    public init(answering opCode: ControlPointOpCode, result: ControlPointResultCode) {
        self.init(requestOpCode: opCode.rawValue, result: result)
    }

    /// Whether this response answers `command`.
    public func answers(_ command: ControlPointCommand) -> Bool {
        requestOpCode == command.opCode.rawValue
    }

    public init(bytes: [UInt8]) throws(PacketError) {
        var reader = ByteReader(bytes)
        let responseCode = try reader.read(UInt8.self)
        guard responseCode == ControlPointOpCode.responseCode.rawValue else {
            throw .unknownOpCode(responseCode)
        }
        requestOpCode = try reader.read(UInt8.self)
        let rawResult = try reader.read(UInt8.self)
        guard let result = ControlPointResultCode(rawValue: rawResult) else {
            throw .reservedValue(field: "Result Code", value: UInt32(rawResult))
        }
        self.result = result
        parameter = reader.readRemaining()
    }

    public func encoded() -> [UInt8] {
        [ControlPointOpCode.responseCode.rawValue, requestOpCode, result.rawValue] + parameter
    }
}
