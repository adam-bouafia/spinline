// swift-tools-version: 6.0
import PackageDescription

// spinline-sim: ride a workout on the virtual trainer from the command line.
// It runs the real FTMS client against the virtual trainer, so it exercises
// the same code path as the app, without a screen or a radio.
let package = Package(
    name: "sim",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "spinline-sim", targets: ["SpinlineSim"])
    ],
    dependencies: [
        .package(path: "../../Packages/Domain"),
        .package(path: "../../Packages/TrainerKit"),
        .package(path: "../../Packages/RideEngine"),
        .package(path: "../../Packages/VirtualTrainer"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "SpinlineSim",
            dependencies: [
                "Domain",
                "TrainerKit",
                "RideEngine",
                "VirtualTrainer",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        )
    ]
)
