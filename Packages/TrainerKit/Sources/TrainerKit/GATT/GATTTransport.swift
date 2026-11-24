/// A value a peripheral sent: a notification or an indication.
public struct GATTValue: Equatable, Sendable {
    public let characteristic: GATTIdentifier
    public let bytes: [UInt8]

    public init(characteristic: GATTIdentifier, bytes: [UInt8]) {
        self.characteristic = characteristic
        self.bytes = bytes
    }
}

/// The GATT operations a trainer client needs, independent of the radio.
///
/// The CoreBluetooth adapter implements this over a real peripheral; the
/// virtual trainer implements it in memory. Everything above it (the FTMS
/// client, view models, the app) runs the same code against both.
public protocol GATTTransport: Sendable {
    /// A new stream of every notification and indication from now on.
    func values() async -> AsyncStream<GATTValue>
    func read(_ characteristic: GATTIdentifier) async throws -> [UInt8]
    /// A write with response: returns when the peripheral acknowledged it.
    func write(_ bytes: [UInt8], to characteristic: GATTIdentifier) async throws
    /// Subscribes to notifications or indications (writes the CCC descriptor).
    func setNotifications(_ enabled: Bool, for characteristic: GATTIdentifier) async throws
}

/// Errors at the GATT level.
public enum GATTError: Error, Equatable, Sendable {
    case notConnected
    case characteristicNotFound(GATTIdentifier)
    /// ATT error: the client wrote before subscribing to indications.
    case clientCharacteristicConfigurationImproperlyConfigured
    /// ATT error: a control point procedure is still running.
    case procedureAlreadyInProgress
}
