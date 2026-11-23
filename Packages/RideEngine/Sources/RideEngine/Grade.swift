import Foundation

/// The steepness of a road, as cyclists and the Bluetooth trainer protocol
/// state it: rise over run, in percent. 100 % is a 45 degree slope.
public struct Grade: Equatable, Comparable, Sendable {
    public var percent: Double

    public init(percent: Double) {
        self.percent = percent
    }

    public static let flat = Grade(percent: 0)

    /// The slope angle in radians: `atan(rise / run)`.
    public var angle: Double { atan(percent / 100) }

    public static func < (lhs: Grade, rhs: Grade) -> Bool { lhs.percent < rhs.percent }
}
