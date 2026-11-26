import Domain
import Testing
import VirtualTrainer

@Suite(.timeLimit(.minutes(1)))
struct VirtualTrainerDiscoveryTests {
    @Test func listsTheVirtualTrainer() async {
        var devices = await VirtualTrainerDiscovery().devices().makeAsyncIterator()
        #expect(await devices.next() == [VirtualTrainerDiscovery.device])
    }

    @Test func connectionRunsInRealTimeAndCloses() async throws {
        // 20 times real time: a notification every 50 ms.
        let discovery = VirtualTrainerDiscovery(timeScale: 20)
        let connection = try await discovery.connect(to: VirtualTrainerDiscovery.device)
        var samples = await connection.samples().makeAsyncIterator()
        try await connection.send(.setTargetPower(watts: 220))

        let first = await samples.next()
        #expect(first?.power != nil)

        await connection.disconnect()
        // Drain anything buffered; the stream must end.
        while await samples.next() != nil {}
    }
}
