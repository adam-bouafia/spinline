/// A connected smart trainer, as the rest of the app sees it.
///
/// Implementations hide the transport: a Bluetooth trainer, the virtual
/// trainer used in tests and demos, or anything else that can report samples
/// and take commands. View models depend on this protocol only.
public protocol TrainerConnection: Sendable {
    /// A new stream of samples, one per notification from the trainer. Each
    /// caller gets its own stream; it ends when the connection closes.
    func samples() async -> AsyncStream<TrainerSample>

    /// Sends a command and returns once the trainer has accepted it.
    ///
    /// - Throws: ``TrainerError`` when the trainer refuses, does not answer,
    ///   or does not support the command.
    func send(_ command: TrainerCommand) async throws
}

/// What the app can ask a trainer to do.
public enum TrainerCommand: Equatable, Sendable {
    /// Start or resume the training session.
    case start
    case pause
    case stop
    /// ERG mode: hold this power whatever the cadence.
    case setTargetPower(watts: Int)
    /// Simulation mode: feel a road with this gradient (percent) and wind (m/s).
    case setSimulation(grade: Double, windSpeed: Double)
}

public enum TrainerError: Error, Equatable, Sendable {
    /// The trainer cannot do this (for example ERG on a trainer without it).
    case notSupported(TrainerCommand)
    /// Another app or device holds control of the trainer.
    case controlNotPermitted
    case invalidParameter(TrainerCommand)
    case operationFailed(TrainerCommand)
    /// No answer within the time limit.
    case timeout
    case disconnected
}
