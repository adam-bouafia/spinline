// swift-tools-version: 6.0
import PackageDescription

// TrainerKit: the Bluetooth side of a smart trainer. Byte-level codecs for the
// Fitness Machine Service and the Heart Rate Service, a virtual trainer that
// speaks the same protocol, and (on Apple platforms) a CoreBluetooth adapter.
let package = Package(
    name: "TrainerKit",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "TrainerKit", targets: ["TrainerKit"])
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(name: "TrainerKit", dependencies: ["Domain"]),
        .testTarget(name: "TrainerKitTests", dependencies: ["TrainerKit"]),
    ]
)
