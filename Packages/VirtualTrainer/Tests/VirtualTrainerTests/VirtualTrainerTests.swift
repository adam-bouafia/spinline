import Domain
import Testing
import TrainerKit
import VirtualTrainer

/// A virtual trainer and the real FTMS client, connected.
struct Rig {
    let trainer: VirtualTrainer
    let client: FTMSTrainer

    static func connected(_ configuration: VirtualTrainer.Configuration = .init()) async throws -> Rig {
        let trainer = VirtualTrainer(configuration: configuration)
        let client = FTMSTrainer(transport: trainer, responseTimeout: .seconds(2))
        try await client.connect()
        return Rig(trainer: trainer, client: client)
    }

    /// Rides `seconds` one second at a time and returns the samples the client
    /// received, one per notification.
    func ride(seconds: Int, samples: inout AsyncStream<TrainerSample>.Iterator) async -> [TrainerSample] {
        var received: [TrainerSample] = []
        for _ in 0..<seconds {
            await trainer.advance(by: 1)
            if let sample = await samples.next() { received.append(sample) }
        }
        return received
    }
}

@Suite(.timeLimit(.minutes(1)))
struct VirtualTrainerTests {
    @Test func clientConnectsAndTakesControl() async throws {
        let rig = try await Rig.connected()
        #expect(await rig.client.hasControl)
        #expect(await rig.trainer.controlGranted)
        #expect(await rig.client.feature?.supportsERG == true)
        #expect(await rig.client.powerRange == SupportedPowerRange(minimum: 0, maximum: 2000, increment: 1))
    }

    @Test func samplesArriveOncePerSecond() async throws {
        let rig = try await Rig.connected()
        var samples = await rig.client.samples().makeAsyncIterator()
        let received = await rig.ride(seconds: 5, samples: &samples)
        #expect(received.count == 5)
        let last = try #require(received.last)
        #expect(last.cadence == 90)
        #expect((last.power ?? 0) > 100)
        #expect((last.speed ?? 0) > 10)
        #expect((last.heartRate ?? 0) > 60)
    }

    @Test func ergTargetIsReachedWithALag() async throws {
        let rig = try await Rig.connected()
        var samples = await rig.client.samples().makeAsyncIterator()
        try await rig.client.send(.setTargetPower(watts: 280))

        let received = await rig.ride(seconds: 12, samples: &samples)
        let first = try #require(received.first?.power)
        let last = try #require(received.last?.power)
        #expect(first < 280)
        #expect(abs(last - 280) <= 2)
        #expect(await rig.trainer.mode == .erg(watts: 280))
    }

    @Test func aSimulatedClimbSlowsTheRiderDown() async throws {
        let flat = try await Rig.connected()
        let climb = try await Rig.connected()
        try await climb.client.send(.setSimulation(grade: 8, windSpeed: 0))
        #expect(await climb.trainer.mode == .simulation(IndoorBikeSimulation(grade: 8)))

        await flat.trainer.advance(by: 120)
        await climb.trainer.advance(by: 120)
        #expect(await climb.trainer.speed < (await flat.trainer.speed) / 2)
    }

    @Test func startCountsTimeAndAStartTwiceFails() async throws {
        let rig = try await Rig.connected()
        try await rig.client.send(.start)
        await rig.trainer.advance(by: 3)
        #expect(abs(await rig.trainer.elapsedTime - 3) < 1e-9)

        await #expect(throws: TrainerError.operationFailed(.start)) {
            try await rig.client.send(.start)
        }
        try await rig.client.send(.pause)
        await rig.trainer.advance(by: 3)
        #expect(abs(await rig.trainer.elapsedTime - 3) < 1e-9)
    }

    @Test func clientTakesControlBackAfterControlPermissionLost() async throws {
        let rig = try await Rig.connected()
        var samples = await rig.client.samples().makeAsyncIterator()
        await rig.trainer.revokeControl(notify: true)
        // The status notification travels through the client's pump; one sample
        // after it proves it was handled.
        await rig.trainer.advance(by: 1)
        _ = await samples.next()
        #expect(await !rig.client.hasControl)

        try await rig.client.send(.setTargetPower(watts: 200))
        #expect(await rig.client.hasControl)
        #expect(await rig.trainer.mode == .erg(watts: 200))
    }

    @Test func clientRecoversWhenControlIsLostSilently() async throws {
        let rig = try await Rig.connected()
        await rig.trainer.revokeControl(notify: false)
        // The client still thinks it has control; the trainer answers Control
        // Not Permitted, the client asks for control and retries.
        try await rig.client.send(.setTargetPower(watts: 210))
        #expect(await rig.trainer.mode == .erg(watts: 210))
    }

    @Test func ergIsRefusedLocallyWhenTheTrainerLacksIt() async throws {
        let feature = FitnessMachineFeature(features: [.powerMeasurement], targetSettings: [.indoorBikeSimulation])
        let rig = try await Rig.connected(.init(feature: feature))
        await #expect(throws: TrainerError.notSupported(.setTargetPower(watts: 200))) {
            try await rig.client.send(.setTargetPower(watts: 200))
        }
        #expect(await rig.trainer.mode == .freeRide)
    }

    @Test func targetsAreClampedToThePowerRange() async throws {
        let range = SupportedPowerRange(minimum: 25, maximum: 1500, increment: 5)
        let rig = try await Rig.connected(.init(powerRange: range))
        try await rig.client.send(.setTargetPower(watts: 2500))
        #expect(await rig.trainer.mode == .erg(watts: 1500))
        try await rig.client.send(.setTargetPower(watts: 233))
        #expect(await rig.trainer.mode == .erg(watts: 235))
    }

    @Test func droppingTheLinkEndsStreamsAndCommandsFail() async throws {
        let rig = try await Rig.connected()
        var samples = await rig.client.samples().makeAsyncIterator()
        await rig.trainer.disconnect()
        #expect(await samples.next() == nil)
        #expect(await !rig.client.isConnected)
        await #expect(throws: TrainerError.disconnected) {
            try await rig.client.send(.start)
        }
    }

    @Test func commandsFromManyTasksRunOneAtATime() async throws {
        let rig = try await Rig.connected()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for watts in stride(from: 100, through: 300, by: 10) {
                group.addTask { try await rig.client.send(.setTargetPower(watts: watts)) }
            }
            try await group.waitForAll()
        }
        guard case .erg = await rig.trainer.mode else {
            Issue.record("expected ERG mode")
            return
        }
    }
}

/// The trainer as a raw FTMS server, without the client in front of it.
@Suite(.timeLimit(.minutes(1)))
struct VirtualTrainerProtocolTests {
    func controlPointAnswers(after writes: [[UInt8]], subscribe: Bool = true) async throws -> [ControlPointResponse] {
        let trainer = VirtualTrainer()
        var values = await trainer.values().makeAsyncIterator()
        if subscribe { try await trainer.setNotifications(true, for: GATTCharacteristic.fitnessMachineControlPoint) }
        var responses: [ControlPointResponse] = []
        for bytes in writes {
            try await trainer.write(bytes, to: GATTCharacteristic.fitnessMachineControlPoint)
            let value = try #require(await values.next())
            responses.append(try ControlPointResponse(bytes: value.bytes))
        }
        return responses
    }

    @Test func writingBeforeSubscribingToIndicationsIsAnATTError() async throws {
        await #expect(throws: GATTError.clientCharacteristicConfigurationImproperlyConfigured) {
            _ = try await controlPointAnswers(after: [[0x00]], subscribe: false)
        }
    }

    @Test func commandsBeforeRequestControlAreNotPermitted() async throws {
        let responses = try await controlPointAnswers(after: [[0x05, 0xC8, 0x00]])
        #expect(responses == [ControlPointResponse(answering: .setTargetPower, result: .controlNotPermitted)])
    }

    @Test func answersEveryKindOfWrite() async throws {
        let responses = try await controlPointAnswers(after: [
            [0x00],  // request control
            [0x05, 0xC8, 0x00],  // 200 W
            [0x05, 0x88, 0x13],  // 5000 W, beyond the range
            [0x05, 0xC8],  // parameter too short
            [0x3C],  // reserved op code
            [0x08, 0x01],  // stop before start
        ])
        #expect(
            responses.map(\.result) == [
                .success, .success, .invalidParameter, .invalidParameter, .opCodeNotSupported, .operationFailed,
            ]
        )
        #expect(responses[4].requestOpCode == 0x3C)
    }

    @Test func unknownCharacteristicsAreNotFound() async throws {
        let trainer = VirtualTrainer()
        await #expect(throws: GATTError.characteristicNotFound(GATTCharacteristic.heartRateMeasurement)) {
            _ = try await trainer.read(GATTCharacteristic.heartRateMeasurement)
        }
    }

    @Test func noBikeDataWithoutASubscription() async throws {
        let trainer = VirtualTrainer()
        var values = await trainer.values().makeAsyncIterator()
        await trainer.advance(by: 3)
        try await trainer.setNotifications(true, for: GATTCharacteristic.indoorBikeData)
        await trainer.advance(by: 1)
        let value = try #require(await values.next())
        let record = try IndoorBikeData(bytes: value.bytes)
        // The first notification after subscribing already shows the 4 s ridden.
        #expect((record.totalDistance ?? 0) > 0)
    }
}
