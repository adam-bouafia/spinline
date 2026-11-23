/// Builds a packet from little-endian integers, front to back.
struct ByteWriter {
    private(set) var bytes: [UInt8] = []

    /// Appends a fixed-width integer, least significant byte first.
    mutating func write<T: FixedWidthInteger>(_ value: T) {
        append(value, byteCount: MemoryLayout<T>.size)
    }

    /// Appends the low 24 bits of `value`.
    mutating func writeUInt24(_ value: UInt32) {
        append(value, byteCount: 3)
    }

    mutating func write(contentsOf other: [UInt8]) {
        bytes.append(contentsOf: other)
    }

    private mutating func append<T: FixedWidthInteger>(_ value: T, byteCount: Int) {
        for index in 0..<byteCount {
            bytes.append(UInt8(truncatingIfNeeded: value >> (8 * index)))
        }
    }
}

/// Conversions between physical values and the scaled integers that Bluetooth
/// sends. A speed of 32.45 km/h at a resolution of 0.01 km/h travels as `3245`.
///
/// The resolution is given as steps per unit (100 for 0.01) because dividing
/// by an integer is exact to the nearest `Double`, while multiplying by 0.01
/// is not: `3245 / 100` is the same `Double` as the literal `32.45`.
enum Scaled {
    /// The integer that represents `value`, rounded to the nearest step and
    /// clamped to the range of `T` so encoding never traps.
    static func raw<T: FixedWidthInteger>(_ value: Double, stepsPerUnit: Double, as _: T.Type = T.self) -> T {
        let steps = (value * stepsPerUnit).rounded()
        guard steps.isFinite else { return 0 }
        if steps <= Double(T.min) { return T.min }
        if steps >= Double(T.max) { return T.max }
        return T(steps)
    }

    static func value<T: FixedWidthInteger>(_ raw: T, stepsPerUnit: Double) -> Double {
        Double(raw) / stepsPerUnit
    }
}
