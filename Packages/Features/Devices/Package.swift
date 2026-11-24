// swift-tools-version: 6.0
import PackageDescription

// Devices feature: find a trainer and connect to it.
let package = Package(
    name: "Devices",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "DevicesCore", targets: ["DevicesCore"]),
        .library(name: "DevicesUI", targets: ["DevicesUI"]),
    ],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../VirtualTrainer"),
    ],
    targets: [
        .target(name: "DevicesCore", dependencies: ["Domain"]),
        .target(name: "DevicesUI", dependencies: ["DevicesCore", "DesignSystem"]),
        .testTarget(name: "DevicesCoreTests", dependencies: ["DevicesCore", "VirtualTrainer"]),
    ]
)
