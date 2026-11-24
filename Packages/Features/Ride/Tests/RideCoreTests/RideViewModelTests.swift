import Domain
import RideCore
import Testing
import TrainerKit
import VirtualTrainer

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RideViewModelTests {
    let trainer: VirtualTrainer
    let viewModel: RideViewModel

    init() async throws {
        trainer = VirtualTrainer()
        let client = FTMSTrainer(transport: trainer)
        try await client.connect()
        viewModel = RideViewModel(connection: client, rider: RiderProfile(ftp: 250))
    }

    @Test func suggestedTargetIsSixtyPercentOfFTPOnFiveWattSteps() {
        #expect(viewModel.suggestedTarget == 150)
    }

    @Test func targetChangesStartFromTheSuggestion() async {
        await viewModel.changeTarget(by: 10)
        #expect(viewModel.targetPower == 160)
        #expect(await trainer.mode == .erg(watts: 160))
        await viewModel.changeTarget(by: -20)
        #expect(viewModel.targetPower == 140)
    }

    @Test func targetNeverGoesBelowZero() async {
        await viewModel.setTargetPower(-50)
        #expect(viewModel.targetPower == 0)
    }

    @Test func rideFreeLeavesErg() async {
        await viewModel.setTargetPower(200)
        await viewModel.rideFree()
        #expect(viewModel.targetPower == nil)
        #expect(await trainer.mode == .simulation(IndoorBikeSimulation()))
    }

    @Test func startAndStop() async {
        await viewModel.start()
        #expect(viewModel.isRiding)
        #expect(await trainer.isStarted)
        await viewModel.stop()
        #expect(!viewModel.isRiding)
    }

    @Test func aRefusedCommandShowsAMessageAndKeepsState() async {
        await viewModel.start()
        await viewModel.start()  // already started: the trainer answers Operation Failed
        #expect(viewModel.isRiding)
        #expect(viewModel.errorMessage == "The trainer could not do that right now.")
    }

    @Test func samplesUpdateTheScreenAndTheZone() async throws {
        let listening = Task { await viewModel.listen() }
        defer { listening.cancel() }
        await viewModel.setTargetPower(240)
        for _ in 0..<10 {
            await trainer.advance(by: 1)
        }
        try await eventually { viewModel.sample.power.map { abs($0 - 240) <= 3 } ?? false }
        #expect(viewModel.zone == .threshold)
        #expect(viewModel.sample.cadence == 90)
    }
}

/// Waits until `condition` holds, yielding so other tasks can deliver values.
@MainActor
func eventually(timeout: Duration = .seconds(5), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("condition not met within \(timeout)")
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
