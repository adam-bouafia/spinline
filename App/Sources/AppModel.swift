import DevicesCore
import Domain
import Foundation
import Observation
import RideCore
import RideEngine
import RoutesCore
import TrainerKit
import VirtualTrainer
import WorkoutsCore

/// The composition root: creates the services and the view models, and
/// passes the trainer connection from the Devices feature to the others.
@MainActor
@Observable
final class AppModel {
    let rider = RiderProfile(riderMass: 75, bikeMass: 8, ftp: 250)
    let devices: DevicesViewModel
    let workouts: [Workout]
    let routes: [BundledRoute]
    private(set) var ride: RideViewModel?
    private(set) var session: WorkoutSessionViewModel?

    @ObservationIgnored private let launch: LaunchOptions

    init(launch: LaunchOptions) {
        self.launch = launch
        let virtualRider = VirtualTrainer.VirtualRider(profile: rider, freeRidePower: 0.6 * Double(rider.ftp))
        let discovery = VirtualTrainerDiscovery(
            configuration: VirtualTrainer.Configuration(rider: virtualRider),
            timeScale: launch.timeScale
        )
        // UI tests and demos use only the virtual trainer, so they never depend
        // on the Bluetooth hardware of the machine they run on.
        if launch.autoConnect {
            devices = DevicesViewModel(discovery: discovery)
        } else {
            devices = DevicesViewModel(
                discovery: CombinedDiscovery(virtual: discovery, bluetooth: BluetoothTrainerDiscovery())
            )
        }
        workouts = Self.bundledWorkouts()
        routes = BundledRoute.all()
    }

    var isConnected: Bool { devices.connection != nil }

    /// Runs once when the window appears.
    func onLaunch() async {
        guard launch.autoConnect else { return }
        await devices.connect(to: VirtualTrainerDiscovery.device)
        connectionChanged()
        if let id = launch.autoStartWorkout, let workout = workouts.first(where: { $0.id == id }) {
            startWorkout(workout)
        }
    }

    /// Builds the ride screen for a new connection, or drops it.
    func connectionChanged() {
        guard let connection = devices.connection else {
            ride = nil
            return
        }
        if ride == nil {
            ride = RideViewModel(connection: connection, rider: rider)
        }
    }

    func startWorkout(_ workout: Workout) {
        guard let connection = devices.connection else { return }
        session = WorkoutSessionViewModel(
            plan: WorkoutPlan(workout: workout, ftp: rider.ftp),
            connection: connection,
            timeScale: launch.timeScale
        )
    }

    func makeRouteRide(_ route: BundledRoute) -> RouteRideViewModel? {
        guard let connection = devices.connection else { return nil }
        return RouteRideViewModel(name: route.name, route: route.index, connection: connection, rider: rider)
    }

    func closeSession() {
        session = nil
    }

    private static func bundledWorkouts() -> [Workout] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Workouts") ?? []
        return (try? WorkoutLibrary.load(urls.compactMap { try? Data(contentsOf: $0) })) ?? []
    }
}
