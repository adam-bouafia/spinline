import Domain
import Foundation
import RideEngine
import Testing
import TrainerKit
import VirtualTrainer
import WorkoutsCore

let intervals = Workout(
    id: "i",
    name: "Intervals",
    steps: [
        WorkoutStep(label: "Warm-up", seconds: 4, target: .ramp(from: 0.5, to: 0.7)),
        WorkoutStep(label: "Hard", seconds: 3, target: .power(1.1)),
        WorkoutStep(label: "Spin", seconds: 3, target: .freeRide),
    ]
)

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WorkoutSessionViewModelTests {
    let trainer: VirtualTrainer
    let session: WorkoutSessionViewModel

    init() async throws {
        trainer = VirtualTrainer()
        let client = FTMSTrainer(transport: trainer)
        try await client.connect()
        session = WorkoutSessionViewModel(plan: WorkoutPlan(workout: intervals, ftp: 200), connection: client)
    }

    @Test func startingSendsStartAndTheFirstTarget() async {
        await session.start()
        #expect(session.state == .running)
        #expect(await trainer.isStarted)
        #expect(await trainer.mode == .erg(watts: 100))
        #expect(session.position?.step.label == "Warm-up")
    }

    @Test func tickingFollowsTheStepsAndFinishes() async {
        await session.start()
        for _ in 0..<4 { await session.tick() }
        #expect(session.position?.step.label == "Hard")
        #expect(await trainer.mode == .erg(watts: 220))

        for _ in 0..<3 { await session.tick() }
        #expect(session.position?.step.label == "Spin")
        #expect(await trainer.mode == .simulation(IndoorBikeSimulation()))

        for _ in 0..<3 { await session.tick() }
        #expect(session.state == .finished)
        #expect(session.progress == 1)
        #expect(await !trainer.isStarted)
    }

    @Test func pauseStopsTheClock() async {
        await session.start()
        await session.pause()
        #expect(session.state == .paused)
        await session.tick()
        #expect(session.elapsed == 0)
        await session.resume()
        await session.tick()
        #expect(session.elapsed == 1)
    }

    @Test func aLostTrainerFailsTheSession() async {
        await session.start()
        await trainer.disconnect()
        // Give the client's pump a moment to see the link drop.
        try? await Task.sleep(for: .milliseconds(50))
        for _ in 0..<4 { await session.tick() }
        guard case .failed = session.state else {
            Issue.record("expected the session to fail, got \(session.state)")
            return
        }
    }

    @Test func runAtHighSpeedCompletesTheWorkout() async throws {
        let client = FTMSTrainer(transport: VirtualTrainer())
        try await client.connect()
        let fast = WorkoutSessionViewModel(
            plan: WorkoutPlan(workout: intervals, ftp: 200),
            connection: client,
            timeScale: 200
        )
        await fast.run()
        #expect(fast.state == .finished)
        #expect(fast.elapsed == 10)
    }
}

struct WorkoutLibraryTests {
    @Test func loadsAndSortsByDuration() throws {
        let long = Data(#"{"id":"l","name":"Long","steps":[{"seconds":600}]}"#.utf8)
        let short = Data(#"{"id":"s","name":"Short","steps":[{"seconds":60,"power":0.5}]}"#.utf8)
        #expect(try WorkoutLibrary.load([long, short]).map(\.id) == ["s", "l"])
    }

    @Test func shippedWorkoutsDecode() throws {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("../../../Content/Workouts").standardizedFileURL
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!files.isEmpty)
        let workouts = try WorkoutLibrary.load(files.map { try Data(contentsOf: $0) })
        #expect(workouts.allSatisfy { $0.duration > 0 })
    }
}

struct TimelineBarTests {
    let plan = WorkoutPlan(workout: intervals, ftp: 200)

    @Test func rampsBecomeStaircasesAndSteadyStepsOneBar() {
        let bars = TimelineBar.bars(for: plan, slicesPerRamp: 4)
        #expect(bars.count == 4 + 1 + 1)
        #expect(bars.first?.start == 0)
        #expect(bars.last?.end == 10)
        #expect(bars[0].watts! < bars[3].watts!)
        #expect(bars[4].watts == 220)
        #expect(bars[4].zone == .vo2Max)
        #expect(bars[5].watts == nil)
    }

    @Test func barsAreContiguous() {
        let bars = TimelineBar.bars(for: plan)
        for (previous, next) in zip(bars, bars.dropFirst()) {
            #expect(abs(previous.end - next.start) < 1e-9)
        }
    }
}

struct ClockTextTests {
    @Test(arguments: [(0, "00:00"), (59, "00:59"), (61, "01:01"), (3599, "59:59"), (3600, "1:00:00"), (-5, "00:00")])
    func formats(seconds: Int, text: String) {
        #expect(clockText(seconds) == text)
    }
}
