#if canImport(CoreBluetooth)
    import CoreBluetooth
    import Testing
    import TrainerKit

    struct CoreBluetoothIdentifierTests {
        @Test(arguments: [GATTService.fitnessMachine, GATTCharacteristic.indoorBikeData, GATTService.heartRate])
        func identifiersSurviveTheTripThroughCBUUID(identifier: GATTIdentifier) {
            #expect(GATTIdentifier(identifier.cbuuid) == identifier)
        }

        @Test func fullUUIDsAreNotSixteenBit() {
            #expect(GATTIdentifier(CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")) == nil)
        }
    }
#endif
