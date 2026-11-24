import DevicesUI
import RideUI
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
        }
    }
}
