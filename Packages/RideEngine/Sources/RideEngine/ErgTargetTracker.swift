/// Decides when to send a new ERG target to the trainer.
///
/// A workout asks for a target every tick, but a trainer handles one control
/// point command at a time and needs a moment to settle. The tracker sends a
/// target only when it changed by at least ``minimumChange`` watts and at most
/// once per ``minimumInterval`` seconds; a step change is never lost, it waits
/// for the interval to pass.
public struct ErgTargetTracker: Equatable, Sendable {
    public let minimumChange: Int
    public let minimumInterval: Double
    /// The last target sent, `nil` before the first one.
    public private(set) var lastSent: Int?
    private var lastSentAt: Double?

    public init(minimumChange: Int = 1, minimumInterval: Double = 1) {
        self.minimumChange = max(minimumChange, 1)
        self.minimumInterval = max(minimumInterval, 0)
    }

    /// The target to send now, or `nil` when nothing should be sent.
    ///
    /// - Parameters:
    ///   - target: the workout's target in watts; `nil` (free ride) sends nothing.
    ///   - time: seconds on a monotonic clock.
    public mutating func update(target: Int?, at time: Double) -> Int? {
        guard let target else { return nil }
        if let lastSent, abs(target - lastSent) < minimumChange { return nil }
        if let lastSentAt, time - lastSentAt < minimumInterval { return nil }
        lastSent = target
        lastSentAt = time
        return target
    }

    /// Forget what was sent, for example after the trainer reconnects and
    /// needs its target again.
    public mutating func reset() {
        lastSent = nil
        lastSentAt = nil
    }
}
