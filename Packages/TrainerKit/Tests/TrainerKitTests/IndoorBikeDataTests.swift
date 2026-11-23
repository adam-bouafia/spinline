import Domain
import Testing

@testable import TrainerKit

/// A packet and the record it must decode to. The bytes are worked out by hand
/// from the specification tables, not produced by the encoder under test.
struct BikeDataFixture: Sendable, CustomTestStringConvertible {
    let name: String
    let bytes: [UInt8]
    let record: IndoorBikeData

    var testDescription: String { name }
}

struct IndoorBikeDataTests {
    static let fixtures: [BikeDataFixture] = [
        BikeDataFixture(
            name: "speed only (flags 0x0000)",
            bytes: [0x00, 0x00, 0xE8, 0x03],
            record: IndoorBikeData(instantaneousSpeed: 10)
        ),
        BikeDataFixture(
            name: "power only, More Data set (flags 0x0041)",
            bytes: [0x41, 0x00, 0x2C, 0x01],
            record: IndoorBikeData(instantaneousPower: 300)
        ),
        BikeDataFixture(
            name: "negative power is sint16",
            bytes: [0x41, 0x00, 0xFB, 0xFF],
            record: IndoorBikeData(instantaneousPower: -5)
        ),
        BikeDataFixture(
            name: "speed, cadence, two-byte resistance, power, heart rate (flags 0x0264)",
            bytes: [0x64, 0x02, 0xAD, 0x0C, 0xB4, 0x00, 0x0C, 0x00, 0xFA, 0x00, 0x8E],
            record: IndoorBikeData(
                instantaneousSpeed: 32.45,
                instantaneousCadence: 90,
                resistanceLevel: 12,
                instantaneousPower: 250,
                heartRate: 142
            )
        ),
        BikeDataFixture(
            name: "every field (flags 0x1FFE)",
            bytes: [
                0xFE, 0x1F,  // flags
                0xC4, 0x09,  // speed 25.00 km/h
                0x92, 0x09,  // average speed 24.50 km/h
                0xAB, 0x00,  // cadence 85.5 rpm
                0xA0, 0x00,  // average cadence 80 rpm
                0x70, 0x11, 0x01,  // distance 70 000 m
                0xFD, 0xFF,  // resistance -3
                0xD2, 0x04,  // power 1234 W
                0xC8, 0x00,  // average power 200 W
                0x96, 0x00, 0x58, 0x02, 0x0A,  // energy 150 kcal, 600 kcal/h, 10 kcal/min
                0x78,  // heart rate 120
                0x41,  // metabolic equivalent 6.5
                0x10, 0x0E,  // elapsed 3600 s
                0x08, 0x07,  // remaining 1800 s
            ],
            record: IndoorBikeData(
                instantaneousSpeed: 25,
                averageSpeed: 24.5,
                instantaneousCadence: 85.5,
                averageCadence: 80,
                totalDistance: 70_000,
                resistanceLevel: -3,
                instantaneousPower: 1234,
                averagePower: 200,
                expendedEnergy: .init(total: 150, perHour: 600, perMinute: 10),
                heartRate: 120,
                metabolicEquivalent: 6.5,
                elapsedTime: 3600,
                remainingTime: 1800
            )
        ),
        BikeDataFixture(
            name: "energy marked Data Not Available",
            bytes: [0x41, 0x01, 0x64, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
            record: IndoorBikeData(instantaneousPower: 100, expendedEnergy: .init())
        ),
    ]

    @Test(arguments: fixtures)
    func decodesFixture(_ fixture: BikeDataFixture) throws {
        #expect(try IndoorBikeData(bytes: fixture.bytes) == fixture.record)
    }

    @Test(arguments: fixtures)
    func encodesFixture(_ fixture: BikeDataFixture) {
        #expect(fixture.record.encoded() == fixture.bytes)
    }

    @Test func moreDataFlagMeansSpeedIsAbsent() throws {
        let record = try IndoorBikeData(bytes: [0x41, 0x00, 0x2C, 0x01])
        #expect(record.flags.contains(.moreData))
        #expect(record.instantaneousSpeed == nil)
    }

    // MARK: Resistance level: two specifications, two sizes

    @Test func oneByteResistanceIsRecognisedByPacketLength() throws {
        let record = try IndoorBikeData(bytes: [0x64, 0x02, 0xAD, 0x0C, 0xB4, 0x00, 0x0C, 0xFA, 0x00, 0x8E])
        #expect(record.resistanceLevel == 12)
        #expect(record.instantaneousPower == 250)
        #expect(record.heartRate == 142)
    }

    @Test(arguments: [IndoorBikeData.ResistanceLevelFormat.sint16, .uint8])
    func resistanceRoundTripsInBothFormats(format: IndoorBikeData.ResistanceLevelFormat) throws {
        let record = IndoorBikeData(instantaneousSpeed: 30, resistanceLevel: 40, instantaneousPower: 180)
        let bytes = record.encoded(resistanceLevelFormat: format)
        #expect(bytes.count == 2 + 2 + format.byteCount + 2)
        #expect(try IndoorBikeData(bytes: bytes) == record)
    }

    // MARK: Robustness

    @Test func ignoresPaddingAfterTheLastField() throws {
        // Some implementations append a byte after the heart rate.
        let padded: [UInt8] = [0x64, 0x02, 0xAD, 0x0C, 0xB4, 0x00, 0x0C, 0x00, 0xFA, 0x00, 0x8E, 0x00]
        let record = try IndoorBikeData(bytes: padded)
        #expect(record.instantaneousPower == 250)
        #expect(record.heartRate == 142)
    }

    @Test(
        arguments: [
            ([], PacketError.truncated(offset: 0, needed: 2)),
            ([0x00], .truncated(offset: 0, needed: 2)),
            ([0x41, 0x00, 0x2C], .truncated(offset: 2, needed: 2)),
            ([0x10, 0x00, 0xE8, 0x03, 0x70, 0x11], .truncated(offset: 4, needed: 3)),
        ] as [([UInt8], PacketError)])
    func throwsWhenAnAnnouncedFieldIsMissing(bytes: [UInt8], error: PacketError) {
        #expect(throws: error) {
            try IndoorBikeData(bytes: bytes)
        }
    }

    @Test func clampsValuesOutsideTheirFieldWhenEncoding() throws {
        let record = IndoorBikeData(instantaneousSpeed: 1_000, instantaneousPower: 40_000, heartRate: 300)
        let decoded = try IndoorBikeData(bytes: record.encoded())
        #expect(decoded.instantaneousSpeed == 655.35)
        #expect(decoded.instantaneousPower == Int(Int16.max))
        #expect(decoded.heartRate == 255)
    }

    // MARK: Mapping to the domain

    @Test func sampleCarriesTheValuesTheAppUses() throws {
        let record = try IndoorBikeData(bytes: [
            0x74, 0x02, 0xAD, 0x0C, 0xB4, 0x00, 0x10, 0x27, 0x00, 0x0C, 0x00, 0xFA, 0x00, 0x8E,
        ])
        #expect(
            record.sample
                == TrainerSample(power: 250, cadence: 90, speed: 32.45, distance: 10_000, heartRate: 142)
        )
    }
}
