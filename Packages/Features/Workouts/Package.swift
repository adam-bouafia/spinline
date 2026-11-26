// swift-tools-version: 6.0
import PackageDescription

// Workouts feature: the workout list, a timeline chart, and a running session
// that drives the trainer in ERG mode.
let package = Package(
    name: "Workouts",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "WorkoutsCore", targets: ["WorkoutsCore"]),
        .library(name: "WorkoutsUI", targets: ["WorkoutsUI"]),
    ],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../RideEngine"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../VirtualTrainer"),
        .package(path: "../../TrainerKit"),
    ],
    targets: [
        .target(name: "WorkoutsCore", dependencies: ["Domain", "RideEngine"]),
        .target(name: "WorkoutsUI", dependencies: ["WorkoutsCore", "DesignSystem"]),
        .testTarget(
            name: "WorkoutsCoreTests",
            dependencies: ["WorkoutsCore", "VirtualTrainer", "TrainerKit"]
        ),
    ]
)
