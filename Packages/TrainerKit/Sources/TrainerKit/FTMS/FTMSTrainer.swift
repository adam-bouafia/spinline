import Domain

/// A smart trainer reached through the Fitness Machine Service: the FTMS
/// client. Works over any ``GATTTransport``, so the same code drives a
/// Bluetooth trainer and the virtual one.
///
/// What it takes care of:
///
/// - **Setup.** Reads the feature and power range, subscribes to Indoor Bike
///   Data, Fitness Machine Status and control point indications (indications
///   must be on before any write), then requests control.
/// - **One procedure at a time.** FTMS allows a single control point
///   procedure in flight. Actors are reentrant (another call can run while
///   one awaits), so commands go through an explicit queue.
/// - **Matching answers.** Each write waits for the indication that names its
///   op code, with a timeout.
/// - **Lost control.** After Control Permission Lost, or a Control Not
///   Permitted answer, it requests control again before giving up.
public actor FTMSTrainer: TrainerConnection {
    private let transport: any GATTTransport
    private let responseTimeout: Duration

    /// What the trainer reported after ``connect()``.
    public private(set) var feature: FitnessMachineFeature?
    public private(set) var powerRange: SupportedPowerRange?
    public private(set) var hasControl = false
    public private(set) var isConnected = false

    private var subscribers: [Int: AsyncStream<TrainerSample>.Continuation] = [:]
    private var nextID = 0
    private var pending: PendingResponse?
    private var commandTail: Task<Void, Never>?
    private var pump: Task<Void, Never>?

    private struct PendingResponse {
        let id: Int
        let opCode: UInt8
        let continuation: CheckedContinuation<ControlPointResponse, any Error>
        let timer: Task<Void, Never>
    }

    public init(transport: any GATTTransport, responseTimeout: Duration = .seconds(3)) {
        self.transport = transport
        self.responseTimeout = responseTimeout
    }

    // MARK: Connection

    /// Discovers what the trainer supports, subscribes, and requests control.
    public func connect() async throws {
        guard !isConnected else { return }
        let values = await transport.values()
        pump = Task {
            for await value in values {
                self.handle(value)
            }
            self.connectionClosed()
        }

        let feature = try FitnessMachineFeature(
            bytes: await transport.read(GATTCharacteristic.fitnessMachineFeature)
        )
        self.feature = feature
        if feature.supportsERG, let bytes = try? await transport.read(GATTCharacteristic.supportedPowerRange) {
            powerRange = try? SupportedPowerRange(bytes: bytes)
        }
        try await transport.setNotifications(true, for: GATTCharacteristic.indoorBikeData)
        try await transport.setNotifications(true, for: GATTCharacteristic.fitnessMachineStatus)
        try await transport.setNotifications(true, for: GATTCharacteristic.fitnessMachineControlPoint)
        isConnected = true
        try await enqueue { try await self.requestControl() }
    }

    /// Stops listening and ends every sample stream.
    public func disconnect() {
        pump?.cancel()
        pump = nil
        connectionClosed()
    }

    // MARK: TrainerConnection

    public func samples() -> AsyncStream<TrainerSample> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: TrainerSample.self,
            bufferingPolicy: .bufferingNewest(32)
        )
        guard isConnected else {
            continuation.finish()
            return stream
        }
        let id = makeID()
        subscribers[id] = continuation
        continuation.onTermination = { _ in
            Task { await self.removeSubscriber(id) }
        }
        return stream
    }

    public func send(_ command: TrainerCommand) async throws {
        guard isConnected else { throw TrainerError.disconnected }
        let controlPointCommand = try translate(command)
        try await enqueue { try await self.perform(controlPointCommand, for: command) }
    }

    // MARK: Procedures

    /// Runs `operation` after every operation enqueued before it.
    private func enqueue(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        let previous = commandTail
        let task = Task {
            await previous?.value
            try await operation()
        }
        commandTail = Task { _ = try? await task.value }
        try await task.value
    }

    private func perform(_ command: ControlPointCommand, for request: TrainerCommand) async throws {
        if !hasControl { try await requestControl() }
        var response = try await execute(command)
        if response.result == .controlNotPermitted {
            // Control can be lost without a status notification; ask once more.
            hasControl = false
            try await requestControl()
            response = try await execute(command)
        }
        switch response.result {
        case .success: return
        case .opCodeNotSupported: throw TrainerError.notSupported(request)
        case .invalidParameter: throw TrainerError.invalidParameter(request)
        case .operationFailed: throw TrainerError.operationFailed(request)
        case .controlNotPermitted:
            hasControl = false
            throw TrainerError.controlNotPermitted
        }
    }

    private func requestControl() async throws {
        let response = try await execute(.requestControl)
        guard response.result == .success else {
            hasControl = false
            throw TrainerError.controlNotPermitted
        }
        hasControl = true
    }

    /// Writes one command and waits for the indication that answers it.
    private func execute(_ command: ControlPointCommand) async throws -> ControlPointResponse {
        guard isConnected else { throw TrainerError.disconnected }
        let id = makeID()
        let bytes = command.encoded()
        let transport = transport
        let timeout = responseTimeout
        return try await withCheckedThrowingContinuation { continuation in
            // Registered before the write: the indication can arrive before
            // the write call returns.
            let timer = Task {
                try? await Task.sleep(for: timeout)
                self.resolve(id, with: .failure(TrainerError.timeout))
            }
            pending = PendingResponse(
                id: id,
                opCode: command.opCode.rawValue,
                continuation: continuation,
                timer: timer
            )
            Task {
                do {
                    try await transport.write(bytes, to: GATTCharacteristic.fitnessMachineControlPoint)
                } catch {
                    self.resolve(id, with: .failure(error))
                }
            }
        }
    }

    private func resolve(_ id: Int, with result: Result<ControlPointResponse, any Error>) {
        guard let pending, pending.id == id else { return }
        self.pending = nil
        pending.timer.cancel()
        pending.continuation.resume(with: result)
    }

    // MARK: Incoming values

    private func handle(_ value: GATTValue) {
        switch value.characteristic {
        case GATTCharacteristic.indoorBikeData:
            guard let data = try? IndoorBikeData(bytes: value.bytes) else { return }
            let sample = data.sample
            for continuation in subscribers.values {
                continuation.yield(sample)
            }
        case GATTCharacteristic.fitnessMachineControlPoint:
            guard let response = try? ControlPointResponse(bytes: value.bytes),
                let pending,
                response.requestOpCode == pending.opCode
            else { return }
            resolve(pending.id, with: .success(response))
        case GATTCharacteristic.fitnessMachineStatus:
            if (try? FitnessMachineStatus(bytes: value.bytes)) == .controlPermissionLost {
                hasControl = false
            }
        default:
            break
        }
    }

    private func connectionClosed() {
        isConnected = false
        hasControl = false
        if let pending { resolve(pending.id, with: .failure(TrainerError.disconnected)) }
        for continuation in subscribers.values {
            continuation.finish()
        }
        subscribers.removeAll()
    }

    // MARK: Helpers

    private func translate(_ command: TrainerCommand) throws -> ControlPointCommand {
        switch command {
        case .start:
            return .startOrResume
        case .pause:
            return .stopOrPause(.pause)
        case .stop:
            return .stopOrPause(.stop)
        case .setTargetPower(let watts):
            guard feature?.supportsERG == true else { throw TrainerError.notSupported(command) }
            return .setTargetPower(watts: powerRange?.validTarget(near: watts) ?? watts)
        case .setSimulation(let grade, let windSpeed):
            guard feature?.supportsSimulation == true else { throw TrainerError.notSupported(command) }
            return .setIndoorBikeSimulation(IndoorBikeSimulation(windSpeed: windSpeed, grade: grade))
        }
    }

    private func removeSubscriber(_ id: Int) {
        subscribers[id] = nil
    }

    private func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }
}
