// swift-tools-version: 6.0
import PackageDescription

// Routes feature: ride a filmed route. The video follows the rider's virtual
// speed and the route's gradient goes to the trainer.
let package = Package(
    name: "Routes",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "RoutesCore", targets: ["RoutesCore"]),
        .library(name: "RoutesUI", targets: ["RoutesUI"]),
    ],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../RideEngine"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../VirtualTrainer"),
        .package(path: "../../TrainerKit"),
    ],
    targets: [
        .target(name: "RoutesCore", dependencies: ["Domain", "RideEngine"]),
        .target(name: "RoutesUI", dependencies: ["RoutesCore", "DesignSystem"]),
        .testTarget(name: "RoutesCoreTests", dependencies: ["RoutesCore", "VirtualTrainer", "TrainerKit"]),
    ]
)
