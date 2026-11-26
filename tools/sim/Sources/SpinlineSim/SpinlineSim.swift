import ArgumentParser
import Domain
import Foundation
import RideEngine
import TrainerKit
import VirtualTrainer

@main
struct SpinlineSim: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spinline-sim",
        abstract: "Ride a workout on the virtual trainer.",
        discussion: """
            The FTMS client talks to the virtual trainer exactly as it would to a \
            Bluetooth trainer: real control point commands, real Indoor Bike Data \
            notifications. ERG targets follow the workout.
            """
    )

    @Option(help: "Workout JSON file.")
    var workout: String

    @Option(help: "Functional threshold power in watts.")
    var ftp = 250

    @Option(help: "Rider mass in kilograms.")
    var mass = 75.0

    @Option(help: "Speed-up over real time; 0 rides as fast as possible.")
    var speed = 0.0

    @Option(help: "Print a line every this many seconds (and at every new step).")
    var every = 30

    mutating func validate() throws {
        guard ftp > 0 else { throw ValidationError("--ftp must be positive") }
        guard every > 0 else { throw ValidationError("--every must be positive") }
        guard speed >= 0 else { throw ValidationError("--speed cannot be negative") }
    }

    func run() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: workout))
        let plan = WorkoutPlan(workout: try JSONDecoder().decode(Workout.self, from: data), ftp: ftp)

        let rider = VirtualTrainer.VirtualRider(
            profile: RiderProfile(riderMass: mass, bikeMass: 8, ftp: ftp),
            freeRidePower: 0.6 * Double(ftp)
        )
        let trainer = VirtualTrainer(configuration: .init(rider: rider))
        let client = FTMSTrainer(transport: trainer)
        try await client.connect()
        var samples = await client.samples().makeAsyncIterator()
        try await client.send(.start)

        print("\(plan.workout.name): \(format(seconds: plan.duration)), FTP \(ftp) W, virtual trainer")
        print(Line.header)

        var controller = WorkoutController(plan: plan)
        var summary = Summary()
        var lastStep = -1
        for second in 0..<plan.duration {
            let elapsed = Double(second)
            guard let position = plan.position(at: elapsed) else { break }
            for command in controller.commands(at: elapsed) {
                try await client.send(command)
            }

            await trainer.advance(by: 1)
            guard let sample = await samples.next() else { throw TrainerError.disconnected }
            summary.add(sample)

            if position.segment.index != lastStep || second % every == 0 {
                print(Line(elapsed: second, position: position, sample: sample).text)
                lastStep = position.segment.index
            }
            if speed > 0 {
                try await Task.sleep(for: .seconds(1 / speed))
            }
        }

        try await client.send(.stop)
        await client.disconnect()
        print(summary.text(duration: plan.duration))
    }
}

/// One row of the live table.
struct Line {
    static let header = [
        "time".leftPadded(5), " ", "step".padding(toLength: 14, withPad: " ", startingAt: 0),
        "target".leftPadded(8), "power".leftPadded(8), "cadence".leftPadded(9), "speed".leftPadded(10),
        "HR".leftPadded(5),
    ].joined()

    let text: String

    init(elapsed: Int, position: WorkoutPlan.Position, sample: TrainerSample) {
        let label = (position.step.label ?? "Free ride").padding(toLength: 14, withPad: " ", startingAt: 0)
        let target = position.targetPower.map { "\($0) W" } ?? "free"
        text = [
            format(seconds: elapsed).leftPadded(5),
            " ", label,
            target.leftPadded(8),
            "\(sample.power ?? 0) W".leftPadded(8),
            "\(Int(sample.cadence ?? 0)) rpm".leftPadded(9),
            String(format: "%.1f km/h", sample.speed ?? 0).leftPadded(10),
            "\(sample.heartRate ?? 0)".leftPadded(5),
        ].joined()
    }
}

/// Totals for the end of the ride.
struct Summary {
    private var count = 0
    private var powerSum = 0
    private var maxHeartRate = 0
    private var distance = 0

    mutating func add(_ sample: TrainerSample) {
        count += 1
        powerSum += sample.power ?? 0
        maxHeartRate = max(maxHeartRate, sample.heartRate ?? 0)
        distance = sample.distance ?? distance
    }

    func text(duration: Int) -> String {
        let averagePower = count > 0 ? powerSum / count : 0
        let kilometres = Double(distance) / 1000
        let averageSpeed = duration > 0 ? kilometres / (Double(duration) / 3600) : 0
        return String(
            format: "Workout complete: %@, %.2f km, average %d W, %.1f km/h, max HR %d",
            format(seconds: duration), kilometres, averagePower, averageSpeed, maxHeartRate
        )
    }
}

func format(seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

extension String {
    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
