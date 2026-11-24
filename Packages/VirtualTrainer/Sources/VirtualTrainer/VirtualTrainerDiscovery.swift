import Domain
import TrainerKit

/// Lists the virtual trainer as a device and connects to it through the real
/// FTMS client, so the app's device screen treats it like any trainer.
public struct VirtualTrainerDiscovery: TrainerDiscovery {
    public static let device = TrainerDevice(id: "virtual-trainer", name: "Virtual trainer", kind: .virtual)

    public let configuration: VirtualTrainer.Configuration
    /// How much faster than real time the trainer runs (demos and UI tests).
    public let timeScale: Double

    public init(configuration: VirtualTrainer.Configuration = .init(), timeScale: Double = 1) {
        self.configuration = configuration
        self.timeScale = timeScale
    }

    public func devices() -> AsyncStream<[TrainerDevice]> {
        // Always in reach; the stream stays open like a scan would.
        AsyncStream { continuation in
            continuation.yield([Self.device])
        }
    }

    public func connect(to device: TrainerDevice) async throws -> any TrainerConnection {
        let trainer = VirtualTrainer(configuration: configuration)
        let client = FTMSTrainer(transport: trainer)
        try await client.connect()
        return VirtualTrainerConnection(trainer: trainer, client: client, timeScale: timeScale)
    }
}

/// A connection to a virtual trainer that keeps the trainer's clock running.
public actor VirtualTrainerConnection: TrainerConnection {
    public let trainer: VirtualTrainer
    private let client: FTMSTrainer
    private var clock: Task<Void, Never>?

    init(trainer: VirtualTrainer, client: FTMSTrainer, timeScale: Double) {
        self.trainer = trainer
        self.client = client
        clock = Task { await trainer.run(timeScale: timeScale) }
    }

    public func samples() async -> AsyncStream<TrainerSample> {
        await client.samples()
    }

    public func send(_ command: TrainerCommand) async throws {
        try await client.send(command)
    }

    public func disconnect() async {
        clock?.cancel()
        clock = nil
        await client.disconnect()
    }
}
