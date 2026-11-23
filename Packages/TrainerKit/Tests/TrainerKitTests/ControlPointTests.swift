import Testing
import TrainerKit

struct CommandFixture: Sendable, CustomTestStringConvertible {
    let command: ControlPointCommand
    let bytes: [UInt8]

    var testDescription: String { "\(command)" }
}

struct ControlPointTests {
    static let commands: [CommandFixture] = [
        CommandFixture(command: .requestControl, bytes: [0x00]),
        CommandFixture(command: .reset, bytes: [0x01]),
        CommandFixture(command: .setTargetSpeed(kilometresPerHour: 30), bytes: [0x02, 0xB8, 0x0B]),
        CommandFixture(command: .setTargetInclination(percent: -2.5), bytes: [0x03, 0xE7, 0xFF]),
        CommandFixture(command: .setTargetResistanceLevel(4.5), bytes: [0x04, 0x2D]),
        CommandFixture(command: .setTargetPower(watts: 200), bytes: [0x05, 0xC8, 0x00]),
        CommandFixture(command: .setTargetPower(watts: 1000), bytes: [0x05, 0xE8, 0x03]),
        CommandFixture(command: .setTargetHeartRate(beatsPerMinute: 150), bytes: [0x06, 0x96]),
        CommandFixture(command: .startOrResume, bytes: [0x07]),
        CommandFixture(command: .stopOrPause(.stop), bytes: [0x08, 0x01]),
        CommandFixture(command: .stopOrPause(.pause), bytes: [0x08, 0x02]),
        CommandFixture(
            command: .setIndoorBikeSimulation(IndoorBikeSimulation(grade: 5.5)),
            bytes: [0x11, 0x00, 0x00, 0x26, 0x02, 0x28, 0x14]
        ),
        CommandFixture(
            command: .setIndoorBikeSimulation(IndoorBikeSimulation(windSpeed: 1.5, grade: -3.25)),
            bytes: [0x11, 0xDC, 0x05, 0xBB, 0xFE, 0x28, 0x14]
        ),
        CommandFixture(command: .setWheelCircumference(millimetres: 2105), bytes: [0x12, 0x3A, 0x52]),
        CommandFixture(command: .setTargetedCadence(revolutionsPerMinute: 92.5), bytes: [0x14, 0xB9, 0x00]),
    ]

    @Test(arguments: commands)
    func encodesCommand(_ fixture: CommandFixture) {
        #expect(fixture.command.encoded() == fixture.bytes)
    }

    @Test(arguments: commands)
    func decodesCommandAsATrainerWould(_ fixture: CommandFixture) throws {
        #expect(try ControlPointCommand(bytes: fixture.bytes) == fixture.command)
    }

    @Test(
        arguments: [
            ([], PacketError.truncated(offset: 0, needed: 1)),
            ([0x05, 0xC8], .unexpectedLength(expected: 3, actual: 2)),
            ([0x07, 0x00], .unexpectedLength(expected: 1, actual: 2)),
            ([0x7F], .unknownOpCode(0x7F)),
            ([0x80, 0x05, 0x01], .unknownOpCode(0x80)),
            ([0x08, 0x03], .reservedValue(field: "Stop or Pause control information", value: 3)),
        ] as [([UInt8], PacketError)])
    func rejectsMalformedCommands(bytes: [UInt8], error: PacketError) {
        #expect(throws: error) {
            try ControlPointCommand(bytes: bytes)
        }
    }

    @Test func targetPowerIsClampedToSint16() throws {
        let command = try ControlPointCommand(bytes: ControlPointCommand.setTargetPower(watts: 100_000).encoded())
        #expect(command == .setTargetPower(watts: Int(Int16.max)))
    }

    // MARK: Responses

    @Test(
        arguments: [
            ([0x80, 0x00, 0x01], ControlPointResponse(answering: .requestControl, result: .success)),
            ([0x80, 0x05, 0x01], ControlPointResponse(answering: .setTargetPower, result: .success)),
            ([0x80, 0x05, 0x05], ControlPointResponse(answering: .setTargetPower, result: .controlNotPermitted)),
            ([0x80, 0x3C, 0x02], ControlPointResponse(requestOpCode: 0x3C, result: .opCodeNotSupported)),
            (
                [0x80, 0x13, 0x01, 0x10, 0x27],
                ControlPointResponse(requestOpCode: 0x13, result: .success, parameter: [0x10, 0x27])
            ),
        ] as [([UInt8], ControlPointResponse)])
    func decodesAndEncodesResponse(bytes: [UInt8], response: ControlPointResponse) throws {
        #expect(try ControlPointResponse(bytes: bytes) == response)
        #expect(response.encoded() == bytes)
    }

    @Test(
        arguments: [
            ([0x05, 0x05, 0x01], PacketError.unknownOpCode(0x05)),
            ([0x80, 0x05], .truncated(offset: 2, needed: 1)),
            ([0x80, 0x05, 0x07], .reservedValue(field: "Result Code", value: 7)),
        ] as [([UInt8], PacketError)])
    func rejectsMalformedResponses(bytes: [UInt8], error: PacketError) {
        #expect(throws: error) {
            try ControlPointResponse(bytes: bytes)
        }
    }

    @Test func responseKnowsWhichCommandItAnswers() {
        let response = ControlPointResponse(answering: .setTargetPower, result: .success)
        #expect(response.answers(.setTargetPower(watts: 150)))
        #expect(!response.answers(.requestControl))
    }
}
