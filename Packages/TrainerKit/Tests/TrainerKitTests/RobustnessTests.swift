import Testing

@testable import TrainerKit

/// A small deterministic generator (SplitMix64), so a failure found here can
/// be replayed exactly.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Bytes from a radio are untrusted input. Every decoder must either return a
/// value or throw a `PacketError`; an out-of-bounds read would crash the app.
struct RobustnessTests {
    static let packetCount = 20_000

    static func randomPackets(seed: UInt64) -> [[UInt8]] {
        var generator = SplitMix64(seed: seed)
        return (0..<packetCount).map { _ in
            let length = Int.random(in: 0...24, using: &generator)
            return (0..<length).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        }
    }

    @Test func randomBytesNeverCrashAnyDecoder() {
        var decoded = 0
        for bytes in Self.randomPackets(seed: 0x5EED) {
            if (try? IndoorBikeData(bytes: bytes)) != nil { decoded += 1 }
            _ = try? ControlPointCommand(bytes: bytes)
            _ = try? ControlPointResponse(bytes: bytes)
            _ = try? FitnessMachineStatus(bytes: bytes)
            _ = try? FitnessMachineFeature(bytes: bytes)
            _ = try? SupportedPowerRange(bytes: bytes)
            _ = try? HeartRateMeasurement(bytes: bytes)
        }
        // Many random packets are valid Indoor Bike Data; the test is about not crashing.
        #expect(decoded > 0)
    }

    @Test func decodedBikeDataSurvivesAnEncodeDecodeRoundTrip() throws {
        for bytes in Self.randomPackets(seed: 0xB1CE) {
            guard let record = try? IndoorBikeData(bytes: bytes) else { continue }
            // Re-encode with the resistance format the decoder picked for these bytes.
            let format = IndoorBikeData.resistanceLevelFormat(flags: record.flags, packetLength: bytes.count)
            #expect(try IndoorBikeData(bytes: record.encoded(resistanceLevelFormat: format)) == record)
        }
    }
}
