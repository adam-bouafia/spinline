import Testing
import TrainerKit

struct FitnessMachineFeatureTests {
    // Features: cadence (bit 1), total distance (bit 2), power measurement (bit 14) = 0x0000_4006.
    // Targets: power (bit 3), indoor bike simulation (bit 13) = 0x0000_2008.
    let bytes: [UInt8] = [0x06, 0x40, 0x00, 0x00, 0x08, 0x20, 0x00, 0x00]

    @Test func decodesBothBitFields() throws {
        let feature = try FitnessMachineFeature(bytes: bytes)
        #expect(feature.features == [.cadence, .totalDistance, .powerMeasurement])
        #expect(feature.targetSettings == [.power, .indoorBikeSimulation])
        #expect(feature.supportsERG)
        #expect(feature.supportsSimulation)
        #expect(feature.encoded() == bytes)
    }

    @Test func trainerWithoutTargetsSupportsNeitherMode() throws {
        let feature = try FitnessMachineFeature(bytes: [0x06, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(!feature.supportsERG)
        #expect(!feature.supportsSimulation)
    }

    @Test func rejectsShortPacket() {
        #expect(throws: PacketError.unexpectedLength(expected: 8, actual: 7)) {
            try FitnessMachineFeature(bytes: Array(bytes.dropLast()))
        }
    }
}

struct SupportedPowerRangeTests {
    @Test func decodesAndEncodes() throws {
        let bytes: [UInt8] = [0x19, 0x00, 0xD0, 0x07, 0x05, 0x00]
        let range = try SupportedPowerRange(bytes: bytes)
        #expect(range == SupportedPowerRange(minimum: 25, maximum: 2000, increment: 5))
        #expect(range.encoded() == bytes)
    }

    @Test(arguments: [(10, 25), (2500, 2000), (102, 100), (103, 105), (25, 25), (2000, 2000)])
    func validTargetIsClampedAndOnAnIncrement(requested: Int, expected: Int) {
        let range = SupportedPowerRange(minimum: 25, maximum: 2000, increment: 5)
        #expect(range.validTarget(near: requested) == expected)
    }
}

struct FitnessMachineStatusTests {
    @Test(
        arguments: [
            ([0x01], FitnessMachineStatus.reset),
            ([0x02, 0x01], .stoppedOrPausedByUser(.stop)),
            ([0x02, 0x02], .stoppedOrPausedByUser(.pause)),
            ([0x03], .stoppedBySafetyKey),
            ([0x04], .startedOrResumedByUser),
            ([0x07, 0x2D], .targetResistanceLevelChanged(4.5)),
            ([0x08, 0xC8, 0x00], .targetPowerChanged(watts: 200)),
            (
                [0x12, 0x00, 0x00, 0x26, 0x02, 0x28, 0x14],
                .indoorBikeSimulationChanged(IndoorBikeSimulation(grade: 5.5))
            ),
            ([0xFF], .controlPermissionLost),
            ([0x05, 0xB8, 0x0B], .other(opCode: 0x05, parameter: [0xB8, 0x0B])),
        ] as [([UInt8], FitnessMachineStatus)])
    func decodesAndEncodesStatus(bytes: [UInt8], status: FitnessMachineStatus) throws {
        #expect(try FitnessMachineStatus(bytes: bytes) == status)
        #expect(status.encoded() == bytes)
    }

    @Test func rejectsTruncatedTargetPowerChange() {
        #expect(throws: PacketError.truncated(offset: 1, needed: 2)) {
            try FitnessMachineStatus(bytes: [0x08, 0xC8])
        }
    }
}
