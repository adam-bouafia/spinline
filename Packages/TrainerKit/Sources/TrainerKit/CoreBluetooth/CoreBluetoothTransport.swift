#if canImport(CoreBluetooth)
    import CoreBluetooth
    import Domain

    extension GATTIdentifier {
        /// The CoreBluetooth form of this identifier.
        public var cbuuid: CBUUID { CBUUID(string: shortString) }

        /// The 16-bit identifier inside a CoreBluetooth UUID, if it is one.
        public init?(_ uuid: CBUUID) {
            let data = uuid.data
            guard data.count == 2 else { return nil }
            self.init(UInt16(data[data.startIndex]) << 8 | UInt16(data[data.startIndex + 1]))
        }
    }

    /// ``GATTTransport`` over a connected `CBPeripheral`.
    ///
    /// CoreBluetooth reports everything through delegate callbacks on one queue.
    /// This class keeps all its state on that queue and turns each callback into
    /// the resumption of a waiting continuation (read, write, subscribe) or a
    /// value on the stream (notifications and indications).
    final class CoreBluetoothTransport: NSObject, GATTTransport, CBPeripheralDelegate, @unchecked Sendable {
        private let peripheral: CBPeripheral
        private let queue: DispatchQueue
        private var characteristics: [GATTIdentifier: CBCharacteristic] = [:]
        private var listeners: [Int: AsyncStream<GATTValue>.Continuation] = [:]
        private var nextID = 0
        private var reads: [GATTIdentifier: CheckedContinuation<[UInt8], any Error>] = [:]
        private var writes: [GATTIdentifier: CheckedContinuation<Void, any Error>] = [:]
        private var subscriptions: [GATTIdentifier: CheckedContinuation<Void, any Error>] = [:]
        private var discovery: CheckedContinuation<Void, any Error>?
        private var servicesLeft = 0

        init(peripheral: CBPeripheral, queue: DispatchQueue) {
            self.peripheral = peripheral
            self.queue = queue
            super.init()
            peripheral.delegate = self
        }

        /// Finds the Fitness Machine and Heart Rate services and their characteristics.
        func discover() async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                queue.async {
                    self.discovery = continuation
                    self.peripheral.discoverServices([GATTService.fitnessMachine.cbuuid, GATTService.heartRate.cbuuid])
                }
            }
        }

        /// The link dropped: every stream ends and every waiting call fails.
        func disconnected() {
            queue.async {
                let error = GATTError.notConnected
                self.discovery?.resume(throwing: error)
                self.discovery = nil
                for item in self.reads.values { item.resume(throwing: error) }
                for item in self.writes.values { item.resume(throwing: error) }
                for item in self.subscriptions.values { item.resume(throwing: error) }
                self.reads = [:]
                self.writes = [:]
                self.subscriptions = [:]
                for item in self.listeners.values { item.finish() }
                self.listeners = [:]
            }
        }

        // MARK: GATTTransport

        func values() async -> AsyncStream<GATTValue> {
            let (stream, continuation) = AsyncStream.makeStream(of: GATTValue.self)
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                queue.async {
                    let id = self.nextID
                    self.nextID += 1
                    self.listeners[id] = continuation
                    continuation.onTermination = { _ in self.queue.async { self.listeners[id] = nil } }
                    done.resume()
                }
            }
            return stream
        }

        func read(_ characteristic: GATTIdentifier) async throws -> [UInt8] {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    guard let target = self.characteristics[characteristic] else {
                        return continuation.resume(throwing: GATTError.characteristicNotFound(characteristic))
                    }
                    self.reads[characteristic] = continuation
                    self.peripheral.readValue(for: target)
                }
            }
        }

        func write(_ bytes: [UInt8], to characteristic: GATTIdentifier) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                queue.async {
                    guard let target = self.characteristics[characteristic] else {
                        return continuation.resume(throwing: GATTError.characteristicNotFound(characteristic))
                    }
                    self.writes[characteristic] = continuation
                    self.peripheral.writeValue(Data(bytes), for: target, type: .withResponse)
                }
            }
        }

        func setNotifications(_ enabled: Bool, for characteristic: GATTIdentifier) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                queue.async {
                    guard let target = self.characteristics[characteristic] else {
                        return continuation.resume(throwing: GATTError.characteristicNotFound(characteristic))
                    }
                    self.subscriptions[characteristic] = continuation
                    self.peripheral.setNotifyValue(enabled, for: target)
                }
            }
        }

        // MARK: CBPeripheralDelegate (called on `queue`)

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
            let services = peripheral.services ?? []
            if let error { return finishDiscovery(error) }
            guard !services.isEmpty else {
                return finishDiscovery(GATTError.characteristicNotFound(GATTService.fitnessMachine))
            }
            servicesLeft = services.count
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }

        func peripheral(
            _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?
        ) {
            for characteristic in service.characteristics ?? [] {
                if let id = GATTIdentifier(characteristic.uuid) { characteristics[id] = characteristic }
            }
            servicesLeft -= 1
            if let error { return finishDiscovery(error) }
            if servicesLeft == 0 { finishDiscovery(nil) }
        }

        func peripheral(
            _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?
        ) {
            guard let id = GATTIdentifier(characteristic.uuid) else { return }
            let bytes = [UInt8](characteristic.value ?? Data())
            if let read = reads.removeValue(forKey: id) {
                if let error { read.resume(throwing: error) } else { read.resume(returning: bytes) }
                return
            }
            guard error == nil else { return }
            let value = GATTValue(characteristic: id, bytes: bytes)
            for item in listeners.values { item.yield(value) }
        }

        func peripheral(
            _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?
        ) {
            guard let id = GATTIdentifier(characteristic.uuid), let write = writes.removeValue(forKey: id) else {
                return
            }
            if let error { write.resume(throwing: error) } else { write.resume() }
        }

        func peripheral(
            _ peripheral: CBPeripheral,
            didUpdateNotificationStateFor characteristic: CBCharacteristic,
            error: (any Error)?
        ) {
            guard let id = GATTIdentifier(characteristic.uuid), let pending = subscriptions.removeValue(forKey: id)
            else {
                return
            }
            if let error { pending.resume(throwing: error) } else { pending.resume() }
        }

        private func finishDiscovery(_ error: (any Error)?) {
            guard let discovery else { return }
            self.discovery = nil
            if let error { discovery.resume(throwing: error) } else { discovery.resume() }
        }
    }
#endif
