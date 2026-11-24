import Domain

/// The virtual trainer and Bluetooth trainers in one list.
struct CombinedDiscovery: TrainerDiscovery {
    let virtual: any TrainerDiscovery
    let bluetooth: any TrainerDiscovery

    func devices() async -> AsyncStream<[TrainerDevice]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [TrainerDevice].self)
        let virtualDevices = await virtual.devices()
        let bluetoothDevices = await bluetooth.devices()
        let task = Task {
            let lists = Lists()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await list in virtualDevices { continuation.yield(await lists.set(virtual: list)) }
                }
                group.addTask {
                    for await list in bluetoothDevices { continuation.yield(await lists.set(bluetooth: list)) }
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func connect(to device: TrainerDevice) async throws -> any TrainerConnection {
        switch device.kind {
        case .virtual: try await virtual.connect(to: device)
        case .bluetooth: try await bluetooth.connect(to: device)
        }
    }

    private actor Lists {
        var virtual: [TrainerDevice] = []
        var bluetooth: [TrainerDevice] = []

        func set(virtual list: [TrainerDevice]) -> [TrainerDevice] {
            virtual = list
            return virtual + bluetooth
        }

        func set(bluetooth list: [TrainerDevice]) -> [TrainerDevice] {
            bluetooth = list
            return virtual + bluetooth
        }
    }
}
