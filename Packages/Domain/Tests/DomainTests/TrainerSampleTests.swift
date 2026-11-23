import Domain
import Testing

struct TrainerSampleTests {
    @Test func mergingKeepsOwnValuesAndFillsGaps() {
        let trainer = TrainerSample(power: 210, cadence: 88, speed: 31.5)
        let strap = TrainerSample(power: 999, heartRate: 142)

        let merged = trainer.merging(strap)

        #expect(merged == TrainerSample(power: 210, cadence: 88, speed: 31.5, heartRate: 142))
    }

    @Test func mergingEmptySamplesGivesEmptySample() {
        #expect(TrainerSample().merging(TrainerSample()) == TrainerSample())
    }
}
