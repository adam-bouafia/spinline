import Domain

/// What to send to the trainer as a workout runs: the decisions, without the
/// sending. The app's session view model and `spinline-sim` both drive their
/// trainer with it.
///
/// - A step with a target: ERG, paced by ``ErgTargetTracker``.
/// - A free-ride step after ERG: release the trainer to a flat road, so the
///   rider's own effort counts.
public struct WorkoutController: Equatable, Sendable {
    public let plan: WorkoutPlan
    private var tracker: ErgTargetTracker
    private var inErg = false

    public init(plan: WorkoutPlan, tracker: ErgTargetTracker = ErgTargetTracker()) {
        self.plan = plan
        self.tracker = tracker
    }

    /// The commands to send at `elapsed` seconds into the workout.
    public mutating func commands(at elapsed: Double) -> [TrainerCommand] {
        guard let position = plan.position(at: elapsed) else { return [] }
        guard let target = position.targetPower else {
            guard inErg else { return [] }
            inErg = false
            tracker.reset()
            return [.setSimulation(grade: 0, windSpeed: 0)]
        }
        guard let watts = tracker.update(target: target, at: elapsed) else { return [] }
        inErg = true
        return [.setTargetPower(watts: watts)]
    }

    /// Call after the trainer reconnected: the next tick sends the target again.
    public mutating func trainerReconnected() {
        tracker.reset()
    }
}
