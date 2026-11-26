// swift-tools-version: 6.0
import PackageDescription

// Domain: entities, use cases and repository protocols. Pure Swift, no
// Bluetooth, no SwiftUI, no networking, so it builds on every platform.
let package = Package(
    name: "Domain",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"])
    ],
    targets: [
        .target(name: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ]
)
