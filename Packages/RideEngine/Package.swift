// swift-tools-version: 6.0
import PackageDescription

// RideEngine: the physics of riding a bike, structured workouts, and the
// mapping from the rider's virtual speed to the route video's playback rate.
// Pure Swift, tested on Linux.
let package = Package(
    name: "RideEngine",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "RideEngine", targets: ["RideEngine"])
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(name: "RideEngine", dependencies: ["Domain"]),
        .testTarget(name: "RideEngineTests", dependencies: ["RideEngine"]),
    ]
)
