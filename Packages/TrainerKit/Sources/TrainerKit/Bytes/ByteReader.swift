/// Reads little-endian integers from a packet, front to back.
///
/// Bluetooth GATT values put the least significant octet first. A `UInt16`
/// sent as `[0x34, 0x12]` is `0x1234`.
struct ByteReader {
    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var remainingCount: Int { bytes.count - offset }

    /// Reads a fixed-width integer (`UInt8`, `UInt16`, `Int16`, `UInt32`, ...).
    mutating func read<T: FixedWidthInteger>(_: T.Type) throws(PacketError) -> T {
        try readLittleEndian(T.self, byteCount: MemoryLayout<T>.size)
    }

    /// Reads a 24-bit unsigned integer, a size Bluetooth uses for distances.
    mutating func readUInt24() throws(PacketError) -> UInt32 {
        try readLittleEndian(UInt32.self, byteCount: 3)
    }

    /// Reads every byte that is left.
    mutating func readRemaining() -> [UInt8] {
        defer { offset = bytes.count }
        return Array(bytes[offset...])
    }

    private mutating func readLittleEndian<T: FixedWidthInteger>(
        _: T.Type,
        byteCount: Int
    ) throws(PacketError) -> T {
        guard remainingCount >= byteCount else {
            throw .truncated(offset: offset, needed: byteCount)
        }
        var value = T.zero
        for index in 0..<byteCount {
            // `<<` never traps in Swift: for a signed T the top byte lands in the
            // sign bit, which is exactly the two's complement bit pattern we want.
            value |= T(truncatingIfNeeded: bytes[offset + index]) << (8 * index)
        }
        offset += byteCount
        return value
    }
}
