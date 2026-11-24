import Domain
import Observation
import RideEngine

/// A workout being ridden: the clock, the current step and target, the live
/// values, and the commands that keep the trainer on target.
@MainActor
@Observable
public final class WorkoutSessionViewModel {
    public enum State: Equatable {
        case ready
        case running
        case paused
        case finished
        case failed(String)
    }

    public let plan: WorkoutPlan
    public private(set) var state: State = .ready
    /// Whole seconds into the workout.
    public private(set) var elapsed = 0
    public private(set) var sample = TrainerSample()

    @ObservationIgnored private let connection: any TrainerConnection
    @ObservationIgnored private var controller: WorkoutController
    @ObservationIgnored private let secondLength: Duration

    /// - Parameter timeScale: workout seconds per real second; above 1 for demos.
    public init(plan: WorkoutPlan, connection: any TrainerConnection, timeScale: Double = 1) {
        self.plan = plan
        self.connection = connection
        controller = WorkoutController(plan: plan)
        secondLength = .milliseconds(Int(1000 / max(timeScale, 0.001)))
    }

    public var position: WorkoutPlan.Position? { plan.position(at: Double(elapsed)) }

    /// Share of the workout done, 0 to 1.
    public var progress: Double {
        plan.duration > 0 ? min(Double(elapsed) / Double(plan.duration), 1) : 0
    }

    public var remaining: Int { max(plan.duration - elapsed, 0) }

    // MARK: Control

    public func start() async {
        guard state == .ready else { return }
        guard await perform(.start) else { return }
        state = .running
        await applyCommands()
    }

    public func pause() async {
        guard state == .running, await perform(.pause) else { return }
        state = .paused
    }

    public func resume() async {
        guard state == .paused, await perform(.start) else { return }
        state = .running
    }

    public func finish() async {
        guard state == .running || state == .paused else { return }
        _ = await perform(.stop)
        if case .failed = state { return }
        state = .finished
    }

    /// Advances the workout clock by one second.
    public func tick() async {
        guard state == .running else { return }
        elapsed += 1
        if elapsed >= plan.duration {
            await finish()
        } else {
            await applyCommands()
        }
    }

    /// Starts the session and ticks once per (scaled) second until it ends or
    /// the calling task is cancelled. The view runs this in its `.task`.
    public func run() async {
        await start()
        let clock = ContinuousClock()
        while state == .running || state == .paused {
            do {
                try await clock.sleep(for: secondLength)
            } catch {
                return
            }
            await tick()
        }
    }

    /// Receives samples until the calling task is cancelled.
    public func listen() async {
        for await sample in await connection.samples() {
            self.sample = sample.merging(self.sample)
        }
    }

    // MARK: Private

    private func applyCommands() async {
        for command in controller.commands(at: Double(elapsed)) {
            guard await perform(command) else { return }
        }
    }

    private func perform(_ command: TrainerCommand) async -> Bool {
        do {
            try await connection.send(command)
            return true
        } catch {
            state = .failed("The trainer stopped answering: \(error)")
            return false
        }
    }
}
