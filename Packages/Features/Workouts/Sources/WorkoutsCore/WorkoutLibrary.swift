import Domain
import Foundation
import RideEngine

/// The workouts the app ships with, read from JSON files.
public enum WorkoutLibrary {
    /// Decodes every file and sorts the workouts by duration, shortest first.
    public static func load(_ files: [Data]) throws -> [Workout] {
        let decoder = JSONDecoder()
        return try files.map { try decoder.decode(Workout.self, from: $0) }
            .sorted { ($0.duration, $0.name) < ($1.duration, $1.name) }
    }
}

/// One bar of the workout chart: a span of time at one power.
public struct TimelineBar: Equatable, Sendable, Identifiable {
    public let id: Int
    /// Seconds from the start.
    public let start: Double
    public let end: Double
    /// Watts, `nil` for a free ride.
    public let watts: Int?
    public let zone: PowerZone?

    /// The bars for `plan`: one per steady step, `slicesPerRamp` per ramp so
    /// the chart shows the slope as a staircase.
    public static func bars(for plan: WorkoutPlan, slicesPerRamp: Int = 12) -> [TimelineBar] {
        var bars: [TimelineBar] = []
        for segment in plan.segments {
            let slices = segment.startPower == segment.endPower ? 1 : max(slicesPerRamp, 1)
            let length = Double(segment.step.seconds) / Double(slices)
            for slice in 0..<slices {
                let start = Double(segment.start) + Double(slice) * length
                let middle = start + length / 2
                let watts = plan.targetPower(at: middle)
                bars.append(
                    TimelineBar(
                        id: bars.count,
                        start: start,
                        end: start + length,
                        watts: watts,
                        zone: watts.map { PowerZone(watts: $0, ftp: plan.ftp) }
                    )
                )
            }
        }
        return bars
    }
}

/// `mm:ss`, or `h:mm:ss` from an hour.
public func clockText(_ seconds: Int) -> String {
    let seconds = max(seconds, 0)
    let hours = seconds / 3600
    let minutes = seconds / 60 % 60
    let rest = seconds % 60
    func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
    return hours > 0 ? "\(hours):\(two(minutes)):\(two(rest))" : "\(two(minutes)):\(two(rest))"
}
