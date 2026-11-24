// swift-tools-version: 6.0
import PackageDescription

// DesignSystem: colours, typography and shared SwiftUI components. The
// sources compile to an empty module where SwiftUI does not exist (Linux).
let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(name: "DesignSystem", dependencies: ["Domain"])
    ]
)
