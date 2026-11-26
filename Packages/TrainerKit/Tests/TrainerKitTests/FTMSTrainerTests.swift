import Domain
import Testing
import TrainerKit

/// A peripheral that has the FTMS characteristics but never answers a write.
actor SilentPeripheral: GATTTransport {
    private var continuations: [AsyncStream<GATTValue>.Continuation] = []
    private(set) var writes: [[UInt8]] = []

    func values() -> AsyncStream<GATTValue> {
        let (stream, continuation) = AsyncStream.makeStream(of: GATTValue.self)
        continuations.append(continuation)
        return stream
    }

    func read(_ characteristic: GATTIdentifier) throws -> [UInt8] {
        FitnessMachineFeature(features: [.powerMeasurement], targetSettings: [.power]).encoded()
    }

    func write(_ bytes: [UInt8], to characteristic: GATTIdentifier) {
        writes.append(bytes)
    }

    func setNotifications(_ enabled: Bool, for characteristic: GATTIdentifier) {}
}

/// A peripheral whose writes fail at the GATT level.
actor BrokenPeripheral: GATTTransport {
    func values() -> AsyncStream<GATTValue> { AsyncStream { _ in } }
    func read(_ characteristic: GATTIdentifier) throws -> [UInt8] {
        FitnessMachineFeature(features: [], targetSettings: [.power]).encoded()
    }
    func write(_ bytes: [UInt8], to characteristic: GATTIdentifier) throws {
        throw GATTError.procedureAlreadyInProgress
    }
    func setNotifications(_ enabled: Bool, for characteristic: GATTIdentifier) {}
}

@Suite(.timeLimit(.minutes(1)))
struct FTMSTrainerTests {
    @Test func aMissingAnswerTimesOut() async throws {
        let peripheral = SilentPeripheral()
        let trainer = FTMSTrainer(transport: peripheral, responseTimeout: .milliseconds(50))
        await #expect(throws: TrainerError.timeout) {
            try await trainer.connect()
        }
        // The client did write Request Control first.
        #expect(await peripheral.writes == [[0x00]])
    }

    @Test func aFailedWriteIsReported() async throws {
        let trainer = FTMSTrainer(transport: BrokenPeripheral(), responseTimeout: .seconds(1))
        await #expect(throws: GATTError.procedureAlreadyInProgress) {
            try await trainer.connect()
        }
    }

    @Test func commandsBeforeConnectingFail() async throws {
        let trainer = FTMSTrainer(transport: SilentPeripheral())
        await #expect(throws: TrainerError.disconnected) {
            try await trainer.send(.start)
        }
    }

    @Test func samplesBeforeConnectingEndAtOnce() async {
        let trainer = FTMSTrainer(transport: SilentPeripheral())
        var samples = await trainer.samples().makeAsyncIterator()
        #expect(await samples.next() == nil)
    }
}
