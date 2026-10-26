// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlucoseBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "GlucoseBar", targets: ["GlucoseBar"])],
    targets: [
        .target(name: "GlucoseCore"),
        .executableTarget(name: "GlucoseBar", dependencies: ["GlucoseCore"]),
        .testTarget(name: "GlucoseCoreTests", dependencies: ["GlucoseCore"])
    ]
)
