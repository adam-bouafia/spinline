import Domain
import RideEngine
import Testing

struct WorkoutPlanTests {
    let workout = Workout(
        id: "test",
        name: "Test",
        steps: [
            WorkoutStep(label: "Warm-up", seconds: 100, target: .ramp(from: 0.5, to: 0.7)),
            WorkoutStep(label: "Effort", seconds: 60, target: .power(1.05), cadence: 95),
            WorkoutStep(label: "Spin", seconds: 40, target: .freeRide),
        ]
    )

    var plan: WorkoutPlan { WorkoutPlan(workout: workout, ftp: 200) }

    @Test func segmentsAreBackToBack() {
        #expect(plan.segments.map(\.start) == [0, 100, 160])
        #expect(plan.segments.map(\.end) == [100, 160, 200])
        #expect(plan.duration == 200)
    }

    @Test func targetsAreFractionsOfFTP() {
        #expect(plan.segments[0].startPower == 100)
        #expect(plan.segments[0].endPower == 140)
        #expect(plan.segments[1].startPower == 210)
        #expect(plan.segments[2].startPower == nil)
    }

    @Test(arguments: [
        (0.0, 100),
        (50.0, 120),
        (99.0, 140),
        (100.0, 210),
        (159.9, 210),
    ])
    func targetPowerFollowsTheSteps(elapsed: Double, watts: Int) {
        #expect(plan.targetPower(at: elapsed) == watts)
    }

    @Test func freeRideHasNoTarget() {
        #expect(plan.targetPower(at: 170) == nil)
        #expect(plan.position(at: 170)?.step.label == "Spin")
    }

    @Test func positionReportsTimeLeft() throws {
        let position = try #require(plan.position(at: 130))
        #expect(position.step.label == "Effort")
        #expect(position.elapsedInStep == 30)
        #expect(position.remainingInStep == 30)
        #expect(position.remainingInWorkout == 70)
        #expect(position.step.cadence == 95)
    }

    @Test(arguments: [-1.0, 200.0, 500.0])
    func noPositionOutsideTheWorkout(elapsed: Double) {
        #expect(plan.position(at: elapsed) == nil)
    }
}

struct ErgTargetTrackerTests {
    @Test func sendsTheFirstTargetAtOnce() {
        var tracker = ErgTargetTracker()
        #expect(tracker.update(target: 150, at: 0) == 150)
    }

    @Test func doesNotRepeatAnUnchangedTarget() {
        var tracker = ErgTargetTracker()
        _ = tracker.update(target: 150, at: 0)
        #expect(tracker.update(target: 150, at: 5) == nil)
    }

    @Test func waitsForTheIntervalButDoesNotLoseAStepChange() {
        var tracker = ErgTargetTracker(minimumInterval: 1)
        _ = tracker.update(target: 150, at: 0)
        #expect(tracker.update(target: 300, at: 0.4) == nil)
        #expect(tracker.update(target: 300, at: 1.0) == 300)
    }

    @Test func ignoresChangesSmallerThanTheMinimum() {
        var tracker = ErgTargetTracker(minimumChange: 5)
        _ = tracker.update(target: 200, at: 0)
        #expect(tracker.update(target: 203, at: 2) == nil)
        #expect(tracker.update(target: 205, at: 3) == 205)
    }

    @Test func freeRideSendsNothing() {
        var tracker = ErgTargetTracker()
        #expect(tracker.update(target: nil, at: 0) == nil)
    }

    @Test func resetSendsTheTargetAgain() {
        var tracker = ErgTargetTracker()
        _ = tracker.update(target: 180, at: 0)
        tracker.reset()
        #expect(tracker.update(target: 180, at: 0.1) == 180)
    }

    @Test func aRampSendsAboutOneCommandPerSecond() {
        let plan = WorkoutPlan(
            workout: Workout(id: "r", name: "Ramp", steps: [WorkoutStep(seconds: 60, target: .ramp(from: 0.5, to: 1))]),
            ftp: 200
        )
        var tracker = ErgTargetTracker()
        var sent: [Int] = []
        for tick in 0..<600 {
            let time = Double(tick) / 10
            if let watts = tracker.update(target: plan.targetPower(at: time), at: time) { sent.append(watts) }
        }
        #expect((58...61).contains(sent.count))
        #expect(sent.first == 100)
        #expect(sent == sent.sorted())
    }
}
