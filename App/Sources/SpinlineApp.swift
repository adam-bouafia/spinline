import SwiftUI

@main
struct SpinlineApp: App {
    @State private var model = AppModel(launch: LaunchOptions(arguments: ProcessInfo.processInfo.arguments))

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .tint(.orange)
        }
    }
}

/// Launch arguments for UI tests and the CI demo video.
struct LaunchOptions {
    /// Connect to the virtual trainer at start.
    var autoConnect = false
    /// Start this workout at launch (by id).
    var autoStartWorkout: String?
    /// Workout seconds per real second.
    var timeScale = 1.0

    init(arguments: [String]) {
        if arguments.contains("-uiTesting") {
            autoConnect = true
            timeScale = 10
        }
        if let index = arguments.firstIndex(of: "-demoWorkout"), arguments.indices.contains(index + 1) {
            autoConnect = true
            autoStartWorkout = arguments[index + 1]
            timeScale = 6
        }
    }
}
