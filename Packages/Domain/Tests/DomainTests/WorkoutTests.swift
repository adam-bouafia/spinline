import Domain
import Foundation
import Testing

struct WorkoutTests {
    static let sweetSpot = Data(
        """
        {
          "id": "sweet-spot-2x10",
          "name": "Sweet spot 2 x 10",
          "steps": [
            { "label": "Warm-up", "seconds": 600, "ramp": { "from": 0.45, "to": 0.75 } },
            { "repeat": 2, "steps": [
              { "label": "Sweet spot", "seconds": 600, "power": 0.9, "cadence": 90 },
              { "label": "Recovery", "seconds": 300, "power": 0.5 }
            ] },
            { "label": "Cool-down", "seconds": 300 }
          ]
        }
        """.utf8
    )

    @Test func decodesStepsAndExpandsRepeatBlocks() throws {
        let workout = try JSONDecoder().decode(Workout.self, from: Self.sweetSpot)

        #expect(workout.id == "sweet-spot-2x10")
        #expect(
            workout.steps.map(\.label) == ["Warm-up", "Sweet spot", "Recovery", "Sweet spot", "Recovery", "Cool-down"])
        #expect(workout.steps[0].target == .ramp(from: 0.45, to: 0.75))
        #expect(workout.steps[1] == WorkoutStep(label: "Sweet spot", seconds: 600, target: .power(0.9), cadence: 90))
        #expect(workout.steps[5].target == .freeRide)
        #expect(workout.duration == 600 + 2 * (600 + 300) + 300)
    }

    @Test func nestedRepeatBlocksMultiply() throws {
        let json = Data(
            """
            { "id": "n", "name": "Nested", "steps": [
              { "repeat": 2, "steps": [ { "repeat": 3, "steps": [ { "seconds": 30, "power": 1.2 } ] } ] }
            ] }
            """.utf8
        )
        let workout = try JSONDecoder().decode(Workout.self, from: json)
        #expect(workout.steps.count == 6)
        #expect(workout.duration == 180)
    }

    @Test func encodingAndDecodingAgainGivesTheSameWorkout() throws {
        let workout = try JSONDecoder().decode(Workout.self, from: Self.sweetSpot)
        let again = try JSONDecoder().decode(Workout.self, from: JSONEncoder().encode(workout))
        #expect(again == workout)
    }

    @Test(arguments: [
        (
            #"{ "seconds": 60, "power": 0.5, "ramp": { "from": 0.5, "to": 0.6 } }"#,
            WorkoutError.stepHasPowerAndRamp(label: nil)
        ),
        (#"{ "label": "Zero", "seconds": 0, "power": 0.5 }"#, .nonPositiveDuration(label: "Zero")),
        (#"{ "repeat": 0, "steps": [] }"#, .invalidRepeatCount(0)),
    ])
    func rejectsInvalidSteps(step: String, error: WorkoutError) {
        let json = Data(#"{ "id": "x", "name": "x", "steps": [ \#(step) ] }"#.utf8)
        #expect(throws: error) {
            try JSONDecoder().decode(Workout.self, from: json)
        }
    }
}

struct RiderProfileTests {
    @Test func totalMassAddsRiderAndBike() {
        #expect(RiderProfile(riderMass: 70, bikeMass: 9, ftp: 250).totalMass == 79)
    }
}
