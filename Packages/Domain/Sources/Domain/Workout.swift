/// A structured workout: a list of timed steps with power targets.
///
/// Targets are fractions of the rider's FTP, so one workout fits every rider.
///
/// JSON form, with `repeat` blocks for intervals:
///
/// ```json
/// {
///   "id": "sweet-spot-2x10",
///   "name": "Sweet spot 2 x 10",
///   "steps": [
///     { "label": "Warm-up", "seconds": 600, "ramp": { "from": 0.45, "to": 0.75 } },
///     { "repeat": 2, "steps": [
///       { "label": "Sweet spot", "seconds": 600, "power": 0.9, "cadence": 90 },
///       { "label": "Recovery", "seconds": 300, "power": 0.5 }
///     ] },
///     { "label": "Cool-down", "seconds": 300 }
///   ]
/// }
/// ```
///
/// A step with neither `power` nor `ramp` is a free ride. Repeat blocks are
/// expanded when decoding, so ``steps`` is always flat.
public struct Workout: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var steps: [WorkoutStep]

    public init(id: String, name: String, steps: [WorkoutStep]) {
        self.id = id
        self.name = name
        self.steps = steps
    }

    /// Length of the whole workout in seconds.
    public var duration: Int { steps.reduce(0) { $0 + $1.seconds } }
}

/// One step of a workout.
public struct WorkoutStep: Equatable, Sendable {
    public var label: String?
    /// Length in seconds.
    public var seconds: Int
    public var target: Target
    /// Suggested cadence in rpm.
    public var cadence: Int?

    public init(label: String? = nil, seconds: Int, target: Target, cadence: Int? = nil) {
        self.label = label
        self.seconds = seconds
        self.target = target
        self.cadence = cadence
    }

    public enum Target: Equatable, Sendable {
        /// Hold a fraction of FTP, for example 0.9 for 90 %.
        case power(Double)
        /// Move linearly from one fraction of FTP to another over the step.
        case ramp(from: Double, to: Double)
        /// No target: the rider chooses.
        case freeRide
    }
}

/// Why a workout file could not be read.
public enum WorkoutError: Error, Equatable, Sendable {
    case stepHasPowerAndRamp(label: String?)
    case nonPositiveDuration(label: String?)
    case invalidRepeatCount(Int)
}

// MARK: - Codable

extension Workout: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, steps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        steps = try container.decode([StepOrBlock].self, forKey: .steps).flatMap(\.steps)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(steps, forKey: .steps)
    }

    /// An entry of a `steps` array: a step, or a repeat block of steps.
    private struct StepOrBlock: Decodable {
        let steps: [WorkoutStep]

        private enum CodingKeys: String, CodingKey {
            case `repeat`, steps
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let count = try container.decodeIfPresent(Int.self, forKey: .repeat) {
                guard count > 0 else { throw WorkoutError.invalidRepeatCount(count) }
                let block = try container.decode([StepOrBlock].self, forKey: .steps).flatMap(\.steps)
                steps = Array(repeating: block, count: count).flatMap { $0 }
            } else {
                steps = [try WorkoutStep(from: decoder)]
            }
        }
    }
}

extension WorkoutStep: Codable {
    private enum CodingKeys: String, CodingKey {
        case label, seconds, power, ramp, cadence
    }

    private struct Ramp: Codable {
        let from: Double
        let to: Double
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        seconds = try container.decode(Int.self, forKey: .seconds)
        cadence = try container.decodeIfPresent(Int.self, forKey: .cadence)
        guard seconds > 0 else { throw WorkoutError.nonPositiveDuration(label: label) }

        let power = try container.decodeIfPresent(Double.self, forKey: .power)
        let ramp = try container.decodeIfPresent(Ramp.self, forKey: .ramp)
        switch (power, ramp) {
        case (.some, .some): throw WorkoutError.stepHasPowerAndRamp(label: label)
        case (.some(let power), nil): target = .power(power)
        case (nil, .some(let ramp)): target = .ramp(from: ramp.from, to: ramp.to)
        case (nil, nil): target = .freeRide
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encode(seconds, forKey: .seconds)
        try container.encodeIfPresent(cadence, forKey: .cadence)
        switch target {
        case .power(let power): try container.encode(power, forKey: .power)
        case .ramp(let from, let to): try container.encode(Ramp(from: from, to: to), forKey: .ramp)
        case .freeRide: break
        }
    }
}
