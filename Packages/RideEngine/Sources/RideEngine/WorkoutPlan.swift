import Domain

/// A workout resolved for one rider: targets in watts and steps placed on a
/// timeline. Answers "where am I and what should I push?" for any elapsed time.
public struct WorkoutPlan: Equatable, Sendable {
    public let workout: Workout
    public let ftp: Int
    /// One segment per step, back to back from time zero.
    public let segments: [Segment]

    public init(workout: Workout, ftp: Int) {
        self.workout = workout
        self.ftp = ftp
        var start = 0
        var segments: [Segment] = []
        for (index, step) in workout.steps.enumerated() {
            segments.append(Segment(index: index, step: step, start: start, ftp: ftp))
            start += step.seconds
        }
        self.segments = segments
    }

    /// Length of the workout in seconds.
    public var duration: Int { segments.last?.end ?? 0 }

    /// The position at `elapsed` seconds, or `nil` before the start and after
    /// the end.
    public func position(at elapsed: Double) -> Position? {
        guard elapsed >= 0, elapsed < Double(duration) else { return nil }
        // Steps are few (tens), so a linear scan is clearer than a binary search.
        guard let segment = segments.first(where: { elapsed < Double($0.end) }) else { return nil }
        let intoStep = elapsed - Double(segment.start)
        return Position(
            segment: segment,
            elapsedInStep: intoStep,
            remainingInStep: Double(segment.step.seconds) - intoStep,
            remainingInWorkout: Double(duration) - elapsed,
            targetPower: segment.targetPower(at: intoStep)
        )
    }

    /// The target in watts at `elapsed` seconds; `nil` in a free ride step
    /// or outside the workout.
    public func targetPower(at elapsed: Double) -> Int? {
        position(at: elapsed)?.targetPower
    }

    public struct Segment: Equatable, Sendable, Identifiable {
        public let index: Int
        public let step: WorkoutStep
        /// Start and end in seconds from the start of the workout.
        public let start: Int
        public var end: Int { start + step.seconds }
        /// Watts at the start and at the end of the step (equal unless it is a
        /// ramp); `nil` for a free ride. For drawing the timeline.
        public let startPower: Int?
        public let endPower: Int?

        public var id: Int { index }

        init(index: Int, step: WorkoutStep, start: Int, ftp: Int) {
            self.index = index
            self.step = step
            self.start = start
            switch step.target {
            case .power(let fraction):
                startPower = Self.watts(fraction, ftp)
                endPower = startPower
            case .ramp(let from, let to):
                startPower = Self.watts(from, ftp)
                endPower = Self.watts(to, ftp)
            case .freeRide:
                startPower = nil
                endPower = nil
            }
        }

        /// The target `seconds` into this step. Ramps move linearly.
        func targetPower(at seconds: Double) -> Int? {
            guard let startPower, let endPower else { return nil }
            let progress = min(max(seconds / Double(step.seconds), 0), 1)
            return Int((Double(startPower) + Double(endPower - startPower) * progress).rounded())
        }

        static func watts(_ fraction: Double, _ ftp: Int) -> Int {
            Int((fraction * Double(ftp)).rounded())
        }
    }

    public struct Position: Equatable, Sendable {
        public let segment: Segment
        public let elapsedInStep: Double
        public let remainingInStep: Double
        public let remainingInWorkout: Double
        public let targetPower: Int?

        public var step: WorkoutStep { segment.step }
    }
}
