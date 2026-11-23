import Testing
import TrainerKit

struct HeartRateMeasurementTests {
    @Test(
        arguments: [
            ([0x00, 0x48], HeartRateMeasurement(heartRate: 72)),
            ([0x04, 0x48], HeartRateMeasurement(heartRate: 72, sensorContact: .notDetected)),
            ([0x06, 0x48], HeartRateMeasurement(heartRate: 72, sensorContact: .detected)),
            ([0x01, 0x2C, 0x01], HeartRateMeasurement(heartRate: 300)),
            ([0x08, 0x50, 0xE8, 0x03], HeartRateMeasurement(heartRate: 80, energyExpended: 1000)),
            (
                [0x16, 0x50, 0x00, 0x04, 0x00, 0x02],
                HeartRateMeasurement(heartRate: 80, sensorContact: .detected, rrIntervals: [1.0, 0.5])
            ),
        ] as [([UInt8], HeartRateMeasurement)])
    func decodesAndEncodes(bytes: [UInt8], measurement: HeartRateMeasurement) throws {
        #expect(try HeartRateMeasurement(bytes: bytes) == measurement)
        #expect(measurement.encoded() == bytes)
    }

    @Test func eightBitFormatWithSixteenBitFlagIsReadAsTwoBytes() throws {
        // A strap may use the 16-bit form for any value.
        let measurement = try HeartRateMeasurement(bytes: [0x01, 0x48, 0x00])
        #expect(measurement.heartRate == 72)
    }

    @Test func contactDetectedBitIsIgnoredWhenContactIsNotSupported() throws {
        let measurement = try HeartRateMeasurement(bytes: [0x02, 0x48])
        #expect(measurement.sensorContact == .notSupported)
    }

    @Test func oddTrailingByteAfterRRIntervalsIsIgnored() throws {
        let measurement = try HeartRateMeasurement(bytes: [0x10, 0x50, 0x00, 0x04, 0x01])
        #expect(measurement.rrIntervals == [1.0])
    }

    @Test(
        arguments: [
            ([], PacketError.truncated(offset: 0, needed: 1)),
            ([0x00], .truncated(offset: 1, needed: 1)),
            ([0x01, 0x2C], .truncated(offset: 1, needed: 2)),
            ([0x08, 0x50, 0xE8], .truncated(offset: 2, needed: 2)),
        ] as [([UInt8], PacketError)])
    func throwsOnTruncatedPacket(bytes: [UInt8], error: PacketError) {
        #expect(throws: error) {
            try HeartRateMeasurement(bytes: bytes)
        }
    }

    @Test func sampleCarriesOnlyTheHeartRate() {
        #expect(HeartRateMeasurement(heartRate: 150).sample.heartRate == 150)
        #expect(HeartRateMeasurement(heartRate: 150).sample.power == nil)
    }
}
