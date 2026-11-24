import Domain
import Observation

/// Lists trainers in reach and holds the connection to the chosen one.
@MainActor
@Observable
public final class DevicesViewModel {
    public enum State: Equatable {
        case idle
        case connecting(TrainerDevice)
        case connected(TrainerDevice)
        case failed(TrainerDevice, message: String)
    }

    public private(set) var devices: [TrainerDevice] = []
    public private(set) var state: State = .idle
    /// The open connection; the composition root hands it to other features.
    public private(set) var connection: (any TrainerConnection)?

    @ObservationIgnored private let discovery: any TrainerDiscovery

    public init(discovery: any TrainerDiscovery) {
        self.discovery = discovery
    }

    public var connectedDevice: TrainerDevice? {
        if case .connected(let device) = state { device } else { nil }
    }

    /// Follows the device list until the calling task is cancelled.
    public func scan() async {
        for await devices in await discovery.devices() {
            self.devices = devices
        }
    }

    public func connect(to device: TrainerDevice) async {
        if case .connecting = state { return }
        await disconnect()
        state = .connecting(device)
        do {
            connection = try await discovery.connect(to: device)
            state = .connected(device)
        } catch {
            state = .failed(device, message: "Could not connect to \(device.name).")
        }
    }

    public func disconnect() async {
        guard let connection else { return }
        self.connection = nil
        state = .idle
        await connection.disconnect()
    }
}
