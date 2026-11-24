import Domain
import Testing

struct PowerZoneTests {
    @Test(arguments: [
        (0, PowerZone.recovery),
        (109, .recovery),
        (110, .endurance),
        (149, .endurance),
        (150, .tempo),
        (180, .threshold),
        (209, .threshold),
        (210, .vo2Max),
        (240, .anaerobic),
        (1000, .anaerobic),
    ])
    func zoneFollowsShareOfFTP(watts: Int, zone: PowerZone) {
        #expect(PowerZone(watts: watts, ftp: 200) == zone)
    }

    @Test func zeroFTPFallsBackToRecovery() {
        #expect(PowerZone(watts: 300, ftp: 0) == .recovery)
    }

    @Test func zonesAreOrdered() {
        #expect(PowerZone.allCases == PowerZone.allCases.sorted())
        #expect(PowerZone.allCases.map(\.lowerBound) == PowerZone.allCases.map(\.lowerBound).sorted())
    }
}
