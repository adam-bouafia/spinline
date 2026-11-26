import Testing
import TrainerKit

struct GATTIdentifierTests {
    @Test(arguments: [
        (GATTService.fitnessMachine, "1826"),
        (GATTService.heartRate, "180D"),
        (GATTCharacteristic.indoorBikeData, "2AD2"),
        (GATTIdentifier(0x00AB), "00AB"),
    ])
    func shortStringHasFourUpperCaseHexDigits(identifier: GATTIdentifier, expected: String) {
        #expect(identifier.shortString == expected)
        #expect(identifier.description == "0x" + expected)
    }
}
