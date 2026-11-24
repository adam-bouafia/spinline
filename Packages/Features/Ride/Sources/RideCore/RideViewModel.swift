import Domain
import Observation

/// The live ride screen: the latest values from the trainer, and ERG control.
@MainActor
@Observable
public final class RideViewModel {
    /// The latest values; a field the trainer stops sending keeps its last value.
    public private(set) var sample = TrainerSample()
    /// The ERG target, `nil` when riding free.
    public private(set) var targetPower: Int?
    public private(set) var isRiding = false
    public private(set) var errorMessage: String?
    public let rider: RiderProfile

    @ObservationIgnored private let connection: any TrainerConnection

    public init(connection: any TrainerConnection, rider: RiderProfile) {
        self.connection = connection
        self.rider = rider
    }

    /// The zone of the current power.
    public var zone: PowerZone? {
        sample.power.map { PowerZone(watts: $0, ftp: rider.ftp) }
    }

    /// The first ERG target offered: 60 % of FTP, on a 5 W step.
    public var suggestedTarget: Int {
        Int((Double(rider.ftp) * 0.6 / 5).rounded()) * 5
    }

    /// Receives samples until the calling task is cancelled (the view's `.task`).
    public func listen() async {
        for await sample in await connection.samples() {
            self.sample = sample.merging(self.sample)
        }
    }

    public func start() async {
        if await perform(.start) { isRiding = true }
    }

    public func stop() async {
        if await perform(.stop) { isRiding = false }
    }

    public func setTargetPower(_ watts: Int) async {
        let watts = max(watts, 0)
        if await perform(.setTargetPower(watts: watts)) { targetPower = watts }
    }

    /// Moves the ERG target by `delta` watts, starting from the suggestion.
    public func changeTarget(by delta: Int) async {
        await setTargetPower((targetPower ?? suggestedTarget) + delta)
    }

    /// Leaves ERG: the trainer rides like a flat road.
    public func rideFree() async {
        if await perform(.setSimulation(grade: 0, windSpeed: 0)) { targetPower = nil }
    }

    private func perform(_ command: TrainerCommand) async -> Bool {
        do {
            try await connection.send(command)
            errorMessage = nil
            return true
        } catch {
            errorMessage = TrainerErrorText.describe(error)
            return false
        }
    }
}

/// Plain-language text for errors shown on screen.
public enum TrainerErrorText {
    public static func describe(_ error: any Error) -> String {
        guard let error = error as? TrainerError else { return "Something went wrong: \(error)" }
        switch error {
        case .notSupported: return "Your trainer does not support this."
        case .controlNotPermitted: return "Another app is controlling the trainer."
        case .invalidParameter: return "The trainer refused that value."
        case .operationFailed: return "The trainer could not do that right now."
        case .timeout: return "The trainer did not answer."
        case .disconnected: return "The trainer is disconnected."
        }
    }
}
