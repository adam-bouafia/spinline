// swift-tools-version: 6.0
import PackageDescription

// Ride feature: the live ride screen. RideCore holds the view model and
// builds everywhere; RideUI holds the SwiftUI views (empty on Linux).
let package = Package(
    name: "Ride",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "RideCore", targets: ["RideCore"]),
        .library(name: "RideUI", targets: ["RideUI"]),
    ],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../VirtualTrainer"),
        .package(path: "../../TrainerKit"),
    ],
    targets: [
        .target(name: "RideCore", dependencies: ["Domain"]),
        .target(name: "RideUI", dependencies: ["RideCore", "DesignSystem"]),
        .testTarget(
            name: "RideCoreTests",
            dependencies: ["RideCore", "VirtualTrainer", "TrainerKit"]
        ),
    ]
)
