// swift-tools-version: 6.0
import PackageDescription

// VirtualTrainer: a smart trainer in software. It speaks FTMS byte for byte
// through the same GATTTransport protocol as a Bluetooth trainer, so the app,
// the tests and CI run without hardware.
let package = Package(
    name: "VirtualTrainer",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "VirtualTrainer", targets: ["VirtualTrainer"])
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../TrainerKit"),
        .package(path: "../RideEngine"),
    ],
    targets: [
        .target(
            name: "VirtualTrainer",
            dependencies: ["Domain", "TrainerKit", "RideEngine"]
        ),
        .testTarget(name: "VirtualTrainerTests", dependencies: ["VirtualTrainer"]),
    ]
)
