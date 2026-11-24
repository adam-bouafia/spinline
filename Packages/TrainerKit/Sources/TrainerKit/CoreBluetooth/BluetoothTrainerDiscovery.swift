#if canImport(CoreBluetooth)
    import CoreBluetooth
    import Domain

    /// Scans for trainers that advertise the Fitness Machine Service and connects
    /// to them through ``FTMSTrainer`` over CoreBluetooth.
    ///
    /// Needs `NSBluetoothAlwaysUsageDescription` in the app's Info.plist. Scanning
    /// starts when the first caller asks for devices and Bluetooth is on; where
    /// Bluetooth is missing (the simulator) the list simply stays empty.
    public final class BluetoothTrainerDiscovery: NSObject, TrainerDiscovery, CBCentralManagerDelegate,
        @unchecked Sendable
    {
        private let queue = DispatchQueue(label: "io.github.adambouafia.spinline.bluetooth")
        private var central: CBCentralManager?
        private var found: [UUID: (peripheral: CBPeripheral, device: TrainerDevice)] = [:]
        private var listeners: [Int: AsyncStream<[TrainerDevice]>.Continuation] = [:]
        private var nextID = 0
        private var connecting: [UUID: CheckedContinuation<Void, any Error>] = [:]
        private var transports: [UUID: CoreBluetoothTransport] = [:]

        public override init() {
            super.init()
        }

        public func devices() async -> AsyncStream<[TrainerDevice]> {
            let (stream, continuation) = AsyncStream.makeStream(of: [TrainerDevice].self)
            queue.async {
                if self.central == nil {
                    self.central = CBCentralManager(delegate: self, queue: self.queue)
                }
                let id = self.nextID
                self.nextID += 1
                self.listeners[id] = continuation
                continuation.onTermination = { _ in self.queue.async { self.listeners[id] = nil } }
                continuation.yield(self.deviceList)
            }
            return stream
        }

        public func connect(to device: TrainerDevice) async throws -> any TrainerConnection {
            guard let id = UUID(uuidString: device.id) else { throw TrainerError.disconnected }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                queue.async {
                    guard let central = self.central, let entry = self.found[id] else {
                        return continuation.resume(throwing: TrainerError.disconnected)
                    }
                    self.connecting[id] = continuation
                    central.connect(entry.peripheral)
                }
            }
            let transport = try await makeTransport(for: id)
            try await transport.discover()
            let trainer = FTMSTrainer(transport: transport)
            try await trainer.connect()
            return trainer
        }

        private func makeTransport(for id: UUID) async throws -> CoreBluetoothTransport {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    guard let entry = self.found[id] else {
                        return continuation.resume(throwing: TrainerError.disconnected)
                    }
                    let transport = CoreBluetoothTransport(peripheral: entry.peripheral, queue: self.queue)
                    self.transports[id] = transport
                    continuation.resume(returning: transport)
                }
            }
        }

        private var deviceList: [TrainerDevice] {
            found.values.map(\.device).sorted { $0.name < $1.name }
        }

        private func publish() {
            let list = deviceList
            for item in listeners.values { item.yield(list) }
        }

        // MARK: CBCentralManagerDelegate (called on `queue`)

        public func centralManagerDidUpdateState(_ central: CBCentralManager) {
            if central.state == .poweredOn {
                central.scanForPeripherals(withServices: [GATTService.fitnessMachine.cbuuid])
            }
        }

        public func centralManager(
            _ central: CBCentralManager,
            didDiscover peripheral: CBPeripheral,
            advertisementData: [String: Any],
            rssi: NSNumber
        ) {
            guard found[peripheral.identifier] == nil else { return }
            let name =
                peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Smart trainer"
            let device = TrainerDevice(id: peripheral.identifier.uuidString, name: name, kind: .bluetooth)
            found[peripheral.identifier] = (peripheral, device)
            publish()
        }

        public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            connecting.removeValue(forKey: peripheral.identifier)?.resume()
        }

        public func centralManager(
            _ central: CBCentralManager,
            didFailToConnect peripheral: CBPeripheral,
            error: (any Error)?
        ) {
            connecting.removeValue(forKey: peripheral.identifier)?.resume(throwing: error ?? TrainerError.disconnected)
        }

        public func centralManager(
            _ central: CBCentralManager,
            didDisconnectPeripheral peripheral: CBPeripheral,
            error: (any Error)?
        ) {
            connecting.removeValue(forKey: peripheral.identifier)?.resume(throwing: TrainerError.disconnected)
            transports.removeValue(forKey: peripheral.identifier)?.disconnected()
        }
    }
#endif
