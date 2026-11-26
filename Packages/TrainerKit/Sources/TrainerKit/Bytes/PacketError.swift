/// Why a Bluetooth packet could not be decoded.
public enum PacketError: Error, Equatable, Sendable {
    /// The packet ended before a field it announced: `needed` bytes were
    /// required at `offset`, fewer were left.
    case truncated(offset: Int, needed: Int)
    /// The packet length does not fit its type.
    case unexpectedLength(expected: Int, actual: Int)
    /// An op code this codec does not implement.
    case unknownOpCode(UInt8)
    /// A field holds a value the specification reserves for future use.
    case reservedValue(field: String, value: UInt32)
}
