import DevicesCore
import Domain
import Testing
import VirtualTrainer

/// A discovery whose connections always fail.
struct UnreachableDiscovery: TrainerDiscovery {
    struct Unreachable: Error {}
    static let device = TrainerDevice(id: "gone", name: "Gone trainer", kind: .bluetooth)

    func devices() -> AsyncStream<[TrainerDevice]> {
        AsyncStream { $0.yield([Self.device]) }
    }

    func connect(to device: TrainerDevice) async throws -> any TrainerConnection {
        throw Unreachable()
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DevicesViewModelTests {
    @Test func scanningListsTheVirtualTrainer() async throws {
        let viewModel = DevicesViewModel(discovery: VirtualTrainerDiscovery())
        let scanning = Task { await viewModel.scan() }
        defer { scanning.cancel() }
        while viewModel.devices.isEmpty { await Task.yield() }
        #expect(viewModel.devices == [VirtualTrainerDiscovery.device])
    }

    @Test func connectingOpensAConnectionAndDisconnectingClosesIt() async throws {
        let viewModel = DevicesViewModel(discovery: VirtualTrainerDiscovery(timeScale: 20))
        await viewModel.connect(to: VirtualTrainerDiscovery.device)
        #expect(viewModel.state == .connected(VirtualTrainerDiscovery.device))
        #expect(viewModel.connectedDevice == VirtualTrainerDiscovery.device)
        let connection = try #require(viewModel.connection)
        try await connection.send(.setTargetPower(watts: 180))

        await viewModel.disconnect()
        #expect(viewModel.state == .idle)
        #expect(viewModel.connection == nil)
        await #expect(throws: TrainerError.disconnected) {
            try await connection.send(.start)
        }
    }

    @Test func aFailedConnectionIsShown() async {
        let viewModel = DevicesViewModel(discovery: UnreachableDiscovery())
        await viewModel.connect(to: UnreachableDiscovery.device)
        #expect(viewModel.state == .failed(UnreachableDiscovery.device, message: "Could not connect to Gone trainer."))
        #expect(viewModel.connection == nil)
    }
}
