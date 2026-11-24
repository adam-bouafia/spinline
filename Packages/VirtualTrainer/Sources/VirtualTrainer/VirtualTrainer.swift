import Domain
import Foundation
import RideEngine
import TrainerKit

/// A smart trainer in software, with a virtual rider on it.
///
/// It is an FTMS server: clients read its feature characteristic, subscribe,
/// write control point commands and receive Indoor Bike Data notifications,
/// all as real FTMS bytes through ``GATTTransport``. A client cannot tell it
/// from a Bluetooth trainer at the protocol level, which is the point: the
/// FTMS client, view models and the app are tested against it.
///
/// Time only moves when told to: ``advance(by:)`` for tests (deterministic),
/// ``run(timeScale:)`` for the app and the command-line ride.
///
/// The model is deliberately simple. The trainer's power follows the ERG
/// target with a first-order lag (about ``Configuration/responseTime``); without
/// a target the rider rides at ``VirtualRider/freeRidePower``. Speed comes from
/// ``RideSimulator`` on the simulated gradient. Heart rate drifts toward
/// `resting + perWatt * power`. Wind in simulation mode is ignored.
public actor VirtualTrainer: GATTTransport {
    public struct Configuration: Sendable {
        public var feature: FitnessMachineFeature
        public var powerRange: SupportedPowerRange
        /// Seconds for the power to cover about 63 % of a step change.
        public var responseTime: Double
        /// Seconds between Indoor Bike Data notifications.
        public var notificationInterval: Double
        public var rider: VirtualRider

        public init(
            feature: FitnessMachineFeature = Self.standardFeature,
            powerRange: SupportedPowerRange = SupportedPowerRange(minimum: 0, maximum: 2000, increment: 1),
            responseTime: Double = 1.5,
            notificationInterval: Double = 1,
            rider: VirtualRider = VirtualRider()
        ) {
            self.feature = feature
            self.powerRange = powerRange
            self.responseTime = responseTime
            self.notificationInterval = notificationInterval
            self.rider = rider
        }

        /// Measures cadence, distance, power, heart rate and elapsed time;
        /// accepts ERG targets and simulated gradients.
        public static let standardFeature = FitnessMachineFeature(
            features: [.cadence, .totalDistance, .powerMeasurement, .heartRateMeasurement, .elapsedTime],
            targetSettings: [.power, .indoorBikeSimulation]
        )
    }

    public struct VirtualRider: Equatable, Sendable {
        public var profile: RiderProfile
        /// Watts the rider pushes when no ERG target is set.
        public var freeRidePower: Double
        /// Pedalling cadence in rpm.
        public var cadence: Double
        public var restingHeartRate: Double
        /// Extra beats per minute per watt, at steady state.
        public var heartRatePerWatt: Double

        public init(
            profile: RiderProfile = RiderProfile(),
            freeRidePower: Double = 150,
            cadence: Double = 90,
            restingHeartRate: Double = 60,
            heartRatePerWatt: Double = 0.4
        ) {
            self.profile = profile
            self.freeRidePower = freeRidePower
            self.cadence = cadence
            self.restingHeartRate = restingHeartRate
            self.heartRatePerWatt = heartRatePerWatt
        }
    }

    public enum Mode: Equatable, Sendable {
        case freeRide
        case erg(watts: Int)
        case simulation(IndoorBikeSimulation)
    }

    public let configuration: Configuration
    public private(set) var mode: Mode = .freeRide
    public private(set) var isStarted = false
    public private(set) var controlGranted = false
    /// The power the trainer measures right now, in watts.
    public private(set) var power: Double = 0
    public private(set) var heartRate: Double
    /// Seconds of training session (counts while started).
    public private(set) var elapsedTime: Double = 0

    private var rider: VirtualRider
    private var simulator: RideSimulator
    private var sinceNotification: Double = 0
    private var subscriptions: Set<GATTIdentifier> = []
    private var listeners: [Int: AsyncStream<GATTValue>.Continuation] = [:]
    private var nextListenerID = 0

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        rider = configuration.rider
        heartRate = configuration.rider.restingHeartRate
        simulator = RideSimulator(physics: CyclingPhysics(rider: configuration.rider.profile))
    }

    /// Speed in m/s.
    public var speed: Double { simulator.speed }
    /// Metres since the start.
    public var distance: Double { simulator.distance }

    // MARK: GATTTransport

    public func values() -> AsyncStream<GATTValue> {
        let (stream, continuation) = AsyncStream.makeStream(of: GATTValue.self)
        let id = nextListenerID
        nextListenerID += 1
        listeners[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.removeListener(id) }
        }
        return stream
    }

    public func read(_ characteristic: GATTIdentifier) throws -> [UInt8] {
        switch characteristic {
        case GATTCharacteristic.fitnessMachineFeature: configuration.feature.encoded()
        case GATTCharacteristic.supportedPowerRange: configuration.powerRange.encoded()
        default: throw GATTError.characteristicNotFound(characteristic)
        }
    }

    public func setNotifications(_ enabled: Bool, for characteristic: GATTIdentifier) throws {
        let notifiable = [
            GATTCharacteristic.indoorBikeData,
            GATTCharacteristic.fitnessMachineStatus,
            GATTCharacteristic.fitnessMachineControlPoint,
        ]
        guard notifiable.contains(characteristic) else {
            throw GATTError.characteristicNotFound(characteristic)
        }
        if enabled {
            subscriptions.insert(characteristic)
        } else {
            subscriptions.remove(characteristic)
        }
    }

    public func write(_ bytes: [UInt8], to characteristic: GATTIdentifier) throws {
        guard characteristic == GATTCharacteristic.fitnessMachineControlPoint else {
            throw GATTError.characteristicNotFound(characteristic)
        }
        // FTMS v1.0 section 4.16.3: no indications, no procedure.
        guard subscriptions.contains(GATTCharacteristic.fitnessMachineControlPoint) else {
            throw GATTError.clientCharacteristicConfigurationImproperlyConfigured
        }
        emit(respond(to: bytes).encoded(), on: GATTCharacteristic.fitnessMachineControlPoint)
    }

    // MARK: Time

    /// Moves simulated time forward, notifying Indoor Bike Data at every
    /// notification interval crossed.
    public func advance(by seconds: Double) {
        let interval = configuration.notificationInterval
        var remaining = seconds
        while remaining > 1e-9 {
            let step = min(remaining, 0.1, interval - sinceNotification)
            tick(step)
            remaining -= step
            sinceNotification += step
            if sinceNotification >= interval - 1e-9 {
                sinceNotification = 0
                notifyBikeData()
            }
        }
    }

    /// Runs in real time (or faster, with `timeScale`) until the task is cancelled.
    public func run(timeScale: Double = 1) async {
        let clock = ContinuousClock()
        let tick = 0.1
        while !Task.isCancelled {
            try? await clock.sleep(for: .milliseconds(100))
            advance(by: tick * timeScale)
        }
    }

    // MARK: Hooks for tests and demos

    /// The rider changes effort (used when there is no ERG target).
    public func setFreeRidePower(_ watts: Double) {
        rider.freeRidePower = max(watts, 0)
    }

    /// Takes control away from the client, as another app would. With
    /// `notify`, the trainer reports Control Permission Lost.
    public func revokeControl(notify: Bool = true) {
        controlGranted = false
        if notify {
            emit(FitnessMachineStatus.controlPermissionLost.encoded(), on: GATTCharacteristic.fitnessMachineStatus)
        }
    }

    /// Drops the link: every value stream ends.
    public func disconnect() {
        for listener in listeners.values {
            listener.finish()
        }
        listeners.removeAll()
        subscriptions.removeAll()
        controlGranted = false
    }

    // MARK: Model

    private func tick(_ dt: Double) {
        let target: Double
        let grade: Grade
        switch mode {
        case .erg(let watts):
            target = Double(watts)
            grade = .flat
        case .simulation(let simulation):
            target = rider.freeRidePower
            grade = Grade(percent: simulation.grade)
        case .freeRide:
            target = rider.freeRidePower
            grade = .flat
        }
        power += (target - power) * (1 - exp(-dt / configuration.responseTime))
        simulator.advance(power: power, grade: grade, duration: dt)
        let steadyHeartRate = rider.restingHeartRate + rider.heartRatePerWatt * power
        heartRate += (steadyHeartRate - heartRate) * (1 - exp(-dt / 20))
        if isStarted { elapsedTime += dt }
    }

    private func notifyBikeData() {
        guard subscriptions.contains(GATTCharacteristic.indoorBikeData) else { return }
        let record = IndoorBikeData(
            instantaneousSpeed: simulator.speed.kilometresPerHour,
            instantaneousCadence: power >= 1 ? rider.cadence : 0,
            totalDistance: UInt32(clamping: Int(simulator.distance)),
            instantaneousPower: Int(power.rounded()),
            heartRate: Int(heartRate.rounded()),
            elapsedTime: Int(elapsedTime)
        )
        emit(record.encoded(), on: GATTCharacteristic.indoorBikeData)
    }

    // MARK: Control point

    private func respond(to bytes: [UInt8]) -> ControlPointResponse {
        let rawOpCode = bytes.first ?? 0
        let command: ControlPointCommand
        do {
            command = try ControlPointCommand(bytes: bytes)
        } catch PacketError.unknownOpCode {
            return ControlPointResponse(requestOpCode: rawOpCode, result: .opCodeNotSupported)
        } catch {
            return ControlPointResponse(requestOpCode: rawOpCode, result: .invalidParameter)
        }

        func answer(_ result: ControlPointResultCode) -> ControlPointResponse {
            ControlPointResponse(answering: command.opCode, result: result)
        }

        if command != .requestControl, !controlGranted {
            return answer(.controlNotPermitted)
        }
        let targets = configuration.feature.targetSettings
        switch command {
        case .requestControl:
            controlGranted = true
        case .reset:
            controlGranted = false
            mode = .freeRide
            isStarted = false
            elapsedTime = 0
        case .setTargetPower(let watts):
            guard targets.contains(.power) else { return answer(.opCodeNotSupported) }
            let range = configuration.powerRange
            guard (range.minimum...range.maximum).contains(watts) else { return answer(.invalidParameter) }
            mode = .erg(watts: watts)
        case .setIndoorBikeSimulation(let simulation):
            guard targets.contains(.indoorBikeSimulation) else { return answer(.opCodeNotSupported) }
            mode = .simulation(simulation)
        case .startOrResume:
            guard !isStarted else { return answer(.operationFailed) }
            isStarted = true
        case .stopOrPause(let control):
            guard isStarted else { return answer(.operationFailed) }
            isStarted = false
            if control == .stop { elapsedTime = 0 }
        default:
            return answer(.opCodeNotSupported)
        }
        return answer(.success)
    }

    private func emit(_ bytes: [UInt8], on characteristic: GATTIdentifier) {
        guard subscriptions.contains(characteristic) else { return }
        let value = GATTValue(characteristic: characteristic, bytes: bytes)
        for listener in listeners.values {
            listener.yield(value)
        }
    }

    private func removeListener(_ id: Int) {
        listeners[id] = nil
    }
}
