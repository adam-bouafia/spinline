import Domain
import RideEngine
import Testing

struct WorkoutControllerTests {
    let plan = WorkoutPlan(
        workout: Workout(
            id: "c",
            name: "Controller",
            steps: [
                WorkoutStep(seconds: 10, target: .power(0.5)),
                WorkoutStep(seconds: 10, target: .freeRide),
                WorkoutStep(seconds: 10, target: .power(1.0)),
            ]
        ),
        ftp: 200
    )

    func commands(from start: Int, to end: Int, _ controller: inout WorkoutController) -> [Int: [TrainerCommand]] {
        var sent: [Int: [TrainerCommand]] = [:]
        for second in start..<end {
            let commands = controller.commands(at: Double(second))
            if !commands.isEmpty { sent[second] = commands }
        }
        return sent
    }

    @Test func sendsEachTargetOnceAndReleasesErgForFreeRide() {
        var controller = WorkoutController(plan: plan)
        let sent = commands(from: 0, to: 30, &controller)
        #expect(
            sent == [
                0: [.setTargetPower(watts: 100)],
                10: [.setSimulation(grade: 0, windSpeed: 0)],
                20: [.setTargetPower(watts: 200)],
            ]
        )
    }

    @Test func sendsNothingAfterTheEnd() {
        var controller = WorkoutController(plan: plan)
        #expect(controller.commands(at: 30).isEmpty)
    }

    @Test func aFreeRideAtTheStartSendsNothing() {
        let plan = WorkoutPlan(
            workout: Workout(id: "f", name: "Free", steps: [WorkoutStep(seconds: 10, target: .freeRide)]),
            ftp: 200
        )
        var controller = WorkoutController(plan: plan)
        #expect(commands(from: 0, to: 10, &controller).isEmpty)
    }

    @Test func reconnectingSendsTheTargetAgain() {
        var controller = WorkoutController(plan: plan)
        _ = controller.commands(at: 0)
        #expect(controller.commands(at: 2).isEmpty)
        controller.trainerReconnected()
        #expect(controller.commands(at: 3) == [.setTargetPower(watts: 100)])
    }
}
