import DevicesUI
import RideUI
import RoutesUI
import SwiftUI
import WorkoutsUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            if let session = model.session {
                WorkoutSessionView(viewModel: session) { model.closeSession() }
            } else {
                tabs
            }
        }
        .task { await model.onLaunch() }
        .onChange(of: model.isConnected) { model.connectionChanged() }
    }

    private var tabs: some View {
        TabView {
            NavigationStack {
                DevicesView(viewModel: model.devices)
            }
            .tabItem { Label("Devices", systemImage: "antenna.radiowaves.left.and.right") }

            NavigationStack {
                if let ride = model.ride {
                    RideView(viewModel: ride)
                } else {
                    ContentUnavailableView(
                        "No trainer",
                        systemImage: "bicycle",
                        description: Text("Connect a trainer on the Devices tab.")
                    )
                    .navigationTitle("Ride")
                }
            }
            .tabItem { Label("Ride", systemImage: "speedometer") }

            NavigationStack {
                WorkoutListView(workouts: model.workouts, ftp: model.rider.ftp, canStart: model.isConnected) {
                    model.startWorkout($0)
                }
            }
            .tabItem { Label("Workouts", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                List(model.routes) { route in
                    NavigationLink(value: route.id) {
                        VStack(alignment: .leading) {
                            Text(route.name).font(.headline)
                            Text(String(format: "%.1f km", route.index.totalDistance / 1000))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("route-\(route.id)")
                }
                .navigationTitle("Routes")
                .navigationDestination(for: String.self) { id in
                    if let route = model.routes.first(where: { $0.id == id }), let ride = model.makeRouteRide(route) {
                        RouteRideView(viewModel: ride, videoURL: route.videoURL)
                    } else {
                        ContentUnavailableView("No trainer", systemImage: "bicycle")
                    }
                }
            }
            .tabItem { Label("Routes", systemImage: "map") }
        }
    }
}
